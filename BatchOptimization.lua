local Batch,parent = torch.class('nn.BatchOptimization', 'nn.Optimization')

-- this is a generic class for any batch optimization modeled after
-- the LBFGS optimization.  It simply provides a batch.evaluate() method
-- which creates a self.parameters and self.gradParameters from your
-- self.model

function Batch:__init(...)
   parent.__init(self)
   xlua.unpack_class(self, {...},
      'BatchOptimization', nil,
      {arg='module', type='nn.Module', help='a module to train', req=true},
      {arg='criterion', type='nn.Criterion', 
       help='a criterion to estimate the error', req=true},
      {arg='maxIterations', type='number', 
       help='maximum nb of iterations per pass (0 = no max)', default=0},
      {arg='maxLineSearch', type='number', 
       help='maximum nb of steps in line search', default=20},
      {arg='sparsity', type='number', 
       help='sparsity coef (Orthantwise C)', default=0},
      {arg='parallelize', type='number', 
       help='parallelize onto N cores (experimental!)', default=1},
      {arg='verbose', type='number', 
       help='verbose level during training [0-2]', default=0}
   )
   self.parameters = nnx.flattenParameters(nnx.getParameters(self.module))
   self.gradParameters = nnx.flattenParameters(nnx.getGradParameters(self.module))
   if self.parallelize > 1 then
      self:setup_mapreduce()
   end
end

function Batch:forward(inputs, targets, options)
   options = options or {}
   if self.parallelize > 1 then
      return self:forward_mapreduce(inputs, targets, options)
   else
      return self:forward_sequential(inputs, targets, options)
   end
end

function Batch:forward_sequential(inputs, targets, options)
   -- (1) construct a closure that compute f(inputs) + df/dW
   --     after each call to that function:
   --       + self.parameters contains the current X vector
   --       + self.gradParameters contains the estimated dF/dX vector
   --       + self.output contains the estimated (average) F(X)
   batch.evaluate
      = function()
           -- reset gradients
           self.gradParameters:zero()
           -- f is the average of all criterions
           self.output = 0
           -- given all inputs, evaluate gradients
           for i = 1,#inputs do
              -- user hook
              if self.prehook then
                 self.prehook(self, {inputs[i], targets[i], options[i]})
              end
              -- estimate f
              local output = self.module:forward(inputs[i])
              local err = self.criterion:forward(output, targets[i])
              self.output = self.output + err
              -- estimate df/dW
              local df_do = self.criterion:backward(output, targets[i])
              self.module:backward(inputs[i], df_do)
              -- user hook
              if self.posthook then
                 self.posthook(self, {inputs[i], targets[i], options[i]})
              end
           end
           -- normalize gradients
           self.gradParameters:div(#inputs)
           -- return average f(X)
           return self.output/#inputs
        end

   -- (3) return current output after optimization
   return self.output
end

function Batch:forward_mapreduce(inputs, targets, options)
   -- parameters
   local P = self.parallelize

   -- transmit user hooks, if defined
   if not self.hooksets then
      if self.prehook then
         if type(self.prehook) == 'string' then
            parallel.children:send(self.prehook)
         else
            print('\r<BatchOptimization> WARNING: when using para||el mode, hooks should be')
            print('\r<BatchOptimization> WARNING: defined as strings. User prehook ignored.')
            parallel.children:send('')
         end
      else
         parallel.children:send('')
      end
      if self.posthook then
         if type(self.posthook) == 'string' then
            parallel.children:send(self.posthook)
         else
            print('\r<BatchOptimization> WARNING: when using para||el mode, hooks should be')
            print('<\rBatchOptimization> WARNING: defined as strings. User posthook ignored.')
            parallel.children:send('')
         end
      else
         parallel.children:send('')
      end
      self.hooksets = true
   end

   -- (0a) replicate output and gradParameters
   local outputsPartial = {}
   local gradParametersPartial = {}

   -- (0b) divide input/target batch into N batches
   local inputss = {}
   local targetss = {}
   local optionss = {}
   for t = 1,P do
      inputss[t] = {}
      targetss[t] = {}
      optionss[t] = {}
      for i = t,#inputs,P do
         table.insert(inputss[t], inputs[i])
         table.insert(targetss[t], targets[i])
         if options then table.insert(optionss[t], options[i]) end
      end
   end

   -- (0c) send mini-batch to all workers
   for t = 1,P do
      parallel.children[t]:send(inputss[t])
      parallel.children[t]:send(targetss[t])
      parallel.children[t]:send(optionss[t])
   end

   -- (1) construct a closure that compute f(inputs) + df/dW
   --     after each call to that function:
   --       + self.parameters contains the current X vector
   --       + self.gradParameters contains the estimated dF/dX vector
   --       + self.output contains the estimated (average) F(X)
   batch.evaluate
      = function()
           batch.evaluate_map()
           return batch.evaluate_reduce()
        end

   -- (1a) the map part of the evaluation: compute partial gradients
   --      in separate threads
   batch.evaluate_map
      = function()
           -- transmit new parameters to all workers
           parallel.children:send(self.parameters)
           -- then wait for all workers to return their partial gradParameters + outputs
           for t = 1,P do
              gradParametersPartial[t] = parallel.children[t]:receive()
              outputsPartial[t] = parallel.children[t]:receive()
           end
           -- force cleanup
           collectgarbage()
        end

   -- (1b) the reduce part of the evaluation: accumulate all
   --      partial estimates of the gradients
   batch.evaluate_reduce
      = function()
           -- accumulate partial gradients, and average
           self.gradParameters:zero()
           for t = 1,P do
              self.gradParameters:add(gradParametersPartial[t])
           end
           self.gradParameters:div(#inputs)
           -- return average f(X)
           self.output = 0
           for t = 1,P do
              self.output = self.output + outputsPartial[t]
           end
           return self.output/#inputs
        end

   -- (3) reset workers so they're ready for next mini-batch
   parallel.children:send('break')

   -- (4) return current output after optimization
   return self.output/#inputs
end

function Batch:setup_mapreduce ()
   -- (0) startup parallel package
   if not xrequire 'parallel' then
      xerror('install parallel for Lua to enable parallel computing (luarocks install parallel)',
             'nn.BatchOptimization')
   end
   parallel.setSharedSize(4*1024*1024)
   local P = self.parallelize

   -- (1) define code for workers
   local worker_code = [[
         -- require packages
         require 'nnx'

         -- retrieve module + criterion at startup
         module = parallel.parent:receive()
         criterion = parallel.parent:receive()

         -- create fake optimizer, for hooks
         optimizer = {module=module, criterion=criterion}

         -- retrieve optional prehook/posthook
         prehook = parallel.parent:receive()
         posthook = parallel.parent:receive()
         if prehook ~= '' then loadstring(prehook)() else prehook = nil end
         if posthook ~= '' then loadstring(posthook)() else posthook = nil end

         -- get pointer to parameter and gradParameter vectors
         parameters = nnx.flattenParameters(nnx.getParameters(module))
         gradParameters = nnx.flattenParameters(nnx.getGradParameters(module))

         -- outter loop: mini-batches
         while true do
            -- receive new mini-batch
            inputs = parallel.parent:receive()
            if type(inputs) == 'string' and inputs == 'break' then break end
            targets = parallel.parent:receive()
            options = parallel.parent:receive()

            -- inner loop: evaluations
            while true do
               -- receive new set of parameters
               newParameters = parallel.parent:receive()
               if type(newParameters) == 'string' and newParameters == 'break' then break end
               parameters:copy(newParameters)

               -- reset gradients
               gradParameters:zero()
               -- f is the average of all criterions
               local f_x = 0
               -- evaluate gradients on inputs for this thread
               for i = 1,#inputs do
                  -- user hook
                  if prehook then
                     prehook(optimizer, {inputs[i], targets[i], options[i]})
                  end
                  -- estimate f
                  local output = module:forward(inputs[i])
                  local err = criterion:forward(output, targets[i])
                  f_x = f_x + err
                  -- estimate df/dW
                  local df_do = criterion:backward(output, targets[i])
                  module:backward(inputs[i], df_do)
                  -- user hook
                  if posthook then
                     posthook(optimizer, {inputs[i], targets[i], options[i]})
                  end
               end

               -- now send back gradParameters + partial output
               parallel.parent:send(gradParameters)
               parallel.parent:send(f_x)

               -- force cleanup
               collectgarbage()
            end
         end
   ]]

   -- (2) startup all workers
   for t = 1,P do
      parallel.run(worker_code)
   end

   -- (3) and send them the module + criterion architecture
   parallel.children:send(self.module)
   parallel.children:send(self.criterion)
end
