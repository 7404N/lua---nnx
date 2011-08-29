local DistNLLCriterion, parent = torch.class('nn.DistNLLCriterion', 'nn.Criterion')

function DistNLLCriterion:__init()
   parent.__init(self)
   -- user options
   self.inputIsProbability = false
   self.inputIsLogProbability = false
   self.targetIsProbability = false
   -- internal
   self.targetSoftMax = nn.SoftMax()
   self.inputLogSoftMax = nn.LogSoftMax()
   self.gradLogInput = torch.Tensor()
end

function DistNLLCriterion:normalize(input, target)
   -- normalize target
   if not self.targetIsProbability then
      self.probTarget = self.targetSoftMax:forward(target)
   else
      self.probTarget = target
   end

   -- normalize input
   if not self.inputIsLogProbability and not self.inputIsProbability then
      self.logProbInput = self.inputLogSoftMax:forward(input)
   elseif not self.inputIsLogProbability then
      print('TODO: implement nn.Log()')
   else
      self.logProbInput = input
   end
end

function DistNLLCriterion:denormalize(input)
   -- denormalize gradients
   if not self.inputIsLogProbability and not self.inputIsProbability then
      self.gradInput = self.inputLogSoftMax:backward(input, self.gradLogInput)
   elseif not self.inputIsLogProbability then
      print('TODO: implement nn.Log()')
   else
      self.gradInput = self.gradLogInput
   end
end

function DistNLLCriterion:forward(input, target)
   self:normalize(input, target)
   self.output = 0
   for i = 1,input:size(1) do
      self.output = self.output - self.logProbInput[i] * self.probTarget[i]
   end
   return self.output
end

function DistNLLCriterion:backward(input, target)
   self:normalize(input, target)
   self.gradLogInput:resizeAs(input)
   for i = 1,input:size(1) do
      self.gradLogInput[i] = -self.probTarget[i]
   end
   self:denormalize(input)
   return self.gradInput
end
