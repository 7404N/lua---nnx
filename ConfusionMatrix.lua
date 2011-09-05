
local ConfusionMatrix = torch.class('nn.ConfusionMatrix')

function ConfusionMatrix:__init(nclasses, classes)
   if type(nclasses) == 'table' then
      classes = nclasses
      nclasses = #classes
   end
   self.mat = lab.zeros(nclasses,nclasses)
   self.valids = lab.zeros(nclasses)
   self.nclasses = nclasses
   self.totalValid = 0
   self.averageValid = 0
   self.classes = classes or {}
end

function ConfusionMatrix:add(prediction, target)
   if type(prediction) == 'number' then
      -- comparing numbers
      self.mat[target][prediction] = self.mat[target][prediction] + 1
   elseif type(target) == 'number' then
      -- prediction is a vector, then target assumed to be an index
      local prediction_1d = torch.Tensor(prediction):resize(self.nclasses)
      local _,prediction = lab.max(prediction_1d)
      self.mat[target][prediction[1]] = self.mat[target][prediction[1]] + 1
   else
      -- both prediction and target are vectors
      local prediction_1d = torch.Tensor(prediction):resize(self.nclasses)
      local target_1d = torch.Tensor(target):resize(self.nclasses)
      local _,prediction = lab.max(prediction_1d)
      local _,target = lab.max(target_1d)
      self.mat[target[1]][prediction[1]] = self.mat[target[1]][prediction[1]] + 1
   end
end

function ConfusionMatrix:zero()
   self.mat:zero()
   self.valids:zero()
   self.totalValid = 0
   self.averageValid = 0
end

function ConfusionMatrix:updateValids()
   local total = 0
   for t = 1,self.nclasses do
      self.valids[t] = self.mat[t][t] / self.mat:select(1,t):sum()
      total = total + self.mat[t][t]
   end
   self.totalValid = total / self.mat:sum()
   self.averageValid = 0
   local nvalids = 0
   for t = 1,self.nclasses do
      if not sys.isNaN(self.valids[t]) then
         self.averageValid = self.averageValid + self.valids[t]
         nvalids = nvalids + 1
      end
   end
   self.averageValid = self.averageValid / nvalids
end

function ConfusionMatrix:__tostring__()
   self:updateValids()
   local str = 'ConfusionMatrix:\n'
   local nclasses = self.nclasses
   str = str .. '['
   for t = 1,nclasses do
      local pclass = self.valids[t] * 100
      pclass = string.format('%2.3f', pclass)
      if t == 1 then
         str = str .. '['
      else
         str = str .. ' ['
      end
      for p = 1,nclasses do
         str = str .. '' .. string.format('%8d', self.mat[t][p])
      end
      if self.classes and self.classes[1] then
         if t == nclasses then
            str = str .. ']]  ' .. pclass .. '% \t[class: ' .. (self.classes[t] or '') .. ']\n'
         else
            str = str .. ']   ' .. pclass .. '% \t[class: ' .. (self.classes[t] or '') .. ']\n'
         end
      else
         if t == nclasses then
            str = str .. ']]  ' .. pclass .. '% \n'
         else
            str = str .. ']   ' .. pclass .. '% \n'
         end
      end
   end
   str = str .. ' + average row correct: ' .. (self.averageValid*100) .. '% \n'
   str = str .. ' + global correct: ' .. (self.totalValid*100) .. '%'
   return str
end

function ConfusionMatrix:write(file)
   file:writeObject(self.mat)
   file:writeObject(self.valids)
   file:writeInt(self.nclasses)
   file:writeInt(self.totalValid)
   file:writeInt(self.averageValid)
   file:writeObject(self.classes)
end

function ConfusionMatrix:read(file)
   self.mat = file:readObject()
   self.valids = file:readObject()
   self.nclasses = file:readInt()
   self.totalValid = file:readInt()
   self.averageValid = file:readInt()
   self.classes = file:readObject()
end
