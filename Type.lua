local Type, parent = torch.class('nn.Type', 'nn.Sequential')

function Type:__init(type)
   parent.__init(self)
   if not type:find('torch%..+Tensor') then
      type = 'torch.' .. type .. 'Tensor'
   end
   self.type = type
   self.defaulttype = torch.getdefaulttensortype()
   self.convert_input = nn.Copy(self.defaulttype, self.type)
   self.convert_gradOutput = nn.Copy(self.defaulttype, self.type)
   self.convert_output = nn.Copy(self.type, self.defaulttype)
   self.convert_gradInput = nn.Copy(self.type, self.defaulttype)
end

function Type:add(module)
   parent.add(self, module:type(self.type))
   return self
end

function Type:forward(input)
   input = self.convert_input:forward(input)
   local output = parent.forward(self, input)
   self.output = self.convert_output:forward(output)
   return self.output
end

function Type:backward(input, gradOutput)
   input = self.convert_input:forward(input)
   gradOutput = self.convert_gradOutput:forward(gradOutput)
   local gradInput = parent.backward(self, input, gradOutput)
   self.gradInput = self.convert_gradInput:forward(gradInput)
   return self.gradInput
end
