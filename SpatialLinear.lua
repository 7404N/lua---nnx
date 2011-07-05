local SpatialLinear, parent = torch.class('nn.SpatialLinear', 'nn.Module')

function SpatialLinear:__init(fanin, fanout)
   parent.__init(self)

   self.fanin = fanin or 1
   self.fanout = fanout or 1

   self.weightDecay = 0   
   self.weight = torch.Tensor(self.fanout, self.fanin)
   self.bias = torch.Tensor(self.fanout)
   self.gradWeight = torch.Tensor(self.fanout, self.fanin)
   self.gradBias = torch.Tensor(self.fanout)
   
   self.output = torch.Tensor(fanout,1,1)
   self.gradInput = torch.Tensor(fanin,1,1)

   self:reset()
end

function SpatialLinear:reset(stdv)
   if stdv then
      stdv = stdv * math.sqrt(3)
   else
      stdv = 1./math.sqrt(self.weight:size(1))
   end
   for i=1,self.weight:size(2) do
      self.weight:select(2, i):apply(function()
                                        return random.uniform(-stdv, stdv)
                                     end)
      self.bias[i] = random.uniform(-stdv, stdv)
   end
end

function SpatialLinear:zeroGradParameters(momentum)
   if momentum then
      self.gradWeight:mul(momentum)
      self.gradBias:mul(momentum)
   else
      self.gradWeight:zero()
      self.gradBias:zero()
   end
end

function SpatialLinear:updateParameters(learningRate)
   self.weight:add(-learningRate, self.gradWeight)
   self.bias:add(-learningRate, self.gradBias)
end

function SpatialLinear:decayParameters(decay)
   self.weight:add(-decay, self.weight)
   self.bias:add(-decay, self.bias)
end

function SpatialLinear:forward(input)
   self.output:resize(self.fanout, input:size(2), input:size(3))
   input.nn.SpatialLinear_forward(self, input)
   return self.output
end

function SpatialLinear:backward(input, gradOutput)
   self.gradInput:resize(self.fanin, input:size(2), input:size(3))
   input.nn.SpatialLinear_backward(self, input, gradOutput)
   return self.gradInput
end

function SpatialLinear:write(file)
   parent.write(self, file)
   file:writeInt(self.fanin)
   file:writeInt(self.fanout)
   file:writeDouble(self.weightDecay)
   file:writeObject(self.weight)
   file:writeObject(self.bias)
   file:writeObject(self.gradWeight)
   file:writeObject(self.gradBias)
end

function SpatialLinear:read(file)
   parent.read(self, file)
   self.fanin = file:readInt()
   self.fanout = file:readInt()
   self.weightDecay = file:readDouble()
   self.weight = file:readObject()
   self.bias = file:readObject()
   self.gradWeight = file:readObject()
   self.gradBias = file:readObject()
end
