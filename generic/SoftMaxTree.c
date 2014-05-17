#ifndef TH_GENERIC_FILE
#define TH_GENERIC_FILE "generic/SoftMaxTree.c"
#else

static int nn_(SoftMaxTree_updateOutput)(lua_State *L)
{
  THTensor *input = luaT_checkudata(L, 2, torch_Tensor);  
  THIntTensor *target = (THIntTensor*)luaT_checkudata(L, 3, "torch.IntTensor");  
  int inputSize = luaT_getfieldcheckint(L, 1, "inputSize");
  long rootId = (long)(luaT_getfieldcheckint(L, 1, "rootId") - 1);
  
  THIntTensor *childParent = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "childParent", "torch.IntTensor");
  THIntTensor *parentChildren = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "parentChildren", "torch.IntTensor");
  
  THTensor *linearOutput = luaT_getfieldcheckudata(L, 1, "_linearOutput", torch_Tensor);
  THTensor *logsoftOutput = luaT_getfieldcheckudata(L, 1, "_logSoftMaxOutput", torch_Tensor);
  
  THTensor *weight = luaT_getfieldcheckudata(L, 1, "weight", torch_Tensor);
  THTensor *bias = luaT_getfieldcheckudata(L, 1, "bias", torch_Tensor);
  THTensor *output = luaT_getfieldcheckudata(L, 1, "output", torch_Tensor);
  
  THIntTensor *node;
  THTensor *nodeWeight, *nodeBias, *nodeOutput, *nodeInput, *nodeInter;
  real *input_data, *output_data;

  long i, d;
  long n = 0;
  
  luaL_argcheck(L, input->nDimension == 2, 2, "2D(batch mode) tensor expected");
  luaL_argcheck(L, input->size[1] == inputSize, 2, "invalid input size");

  node = THIntTensor_new();
  nodeWeight = THTensor_(new)();
  nodeBias = THTensor_(new)();
  nodeOutput = THTensor_(new)();
  nodeInput = THTensor_(new)();
  nodeInter = THTensor_(new)();
  
  THTensor_(resize1d)(output, input->size[0]);
  
  for(i = 0; i < input->size[0]; i++)
  {
    long childId = (long)(THIntTensor_get1d(target, i)) - 1;
    accreal narrowsum = 0;
    THTensor_(select)(nodeInput, input, 0, i);
    while(1)
    {
      long parentId, parentIdx, childIdx, nChildren;
      /* get next Node in Tree */
      THIntTensor_select(node, childParent, 0, childId);
      parentId = (long)(THIntTensor_get1d(node, 0)) - 1;
      childIdx = (long)(THIntTensor_get1d(node, 1)) - 1;
      
      luaL_argcheck(L, parentId != -2, 2, "Non-root node has no parent in tree.");
      
      THIntTensor_select(node, parentChildren, 0, parentId);
      parentIdx = (long)(THIntTensor_get1d(node, 0)) - 1;
      nChildren = (long)(THIntTensor_get1d(node, 1));
      
      // we use these to keep intermediate results for later backprop
      THTensor_(resize1d)(linearOutput, n+nChildren);
      THTensor_(resize1d)(logsoftOutput, n+nChildren);
  
      /* Linear */
      THTensor_(narrow)(nodeWeight, weight, 0, parentIdx, nChildren);
      THTensor_(narrow)(nodeBias, bias, 0, parentIdx, nChildren);
      THTensor_(narrow)(nodeOutput, linearOutput, 0, n, nChildren);
      
      THTensor_(addmv)(nodeOutput, 1, nodeBias, 1, nodeWeight, nodeInput);
      
      /* LogSoftMax */
      THTensor_(set)(nodeInter, nodeOutput);
      THTensor_(narrow)(nodeOutput, logsoftOutput, 0, n, nChildren);
      
      input_data = THTensor_(data)(nodeInter);
      output_data = THTensor_(data)(nodeOutput);
      
      accreal logsum = 0;
      real maxInput = -THInf;
      
      for(d = 0; d < nChildren; d++)
        maxInput = THMax(maxInput, input_data[d]);

      for(d = 0; d < nChildren; d++)
        logsum += THExpMinusApprox(maxInput-input_data[d]);
      logsum = maxInput + log(logsum);

      for(d = 0; d < nChildren; d++)
        output_data[d] = input_data[d] - logsum;
        
      /* Narrow */
      THTensor_(set)(nodeInter, nodeOutput);
      THTensor_(narrow)(nodeOutput, nodeInter, 0, childIdx, 1); //we might have to store childIdx in backprop
      
      /* CAddTable (without log, would have been CMulTable) */
      narrowsum += THTensor_(get1d)(nodeOutput, 0);
      n += nChildren;
      /* Break when root is reached */
      if (parentId == rootId) 
      {
        break;
      }
      childId = parentId;
    }
    THTensor_(set1d)(output, i, narrowsum);  
  }
  
  THIntTensor_free(node);
  THTensor_(free)(nodeWeight);
  THTensor_(free)(nodeBias);
  THTensor_(free)(nodeOutput);
  THTensor_(free)(nodeInput);
  THTensor_(free)(nodeInter);
  return 1;
}

static int nn_(SoftMaxTree_updateGradInput)(lua_State *L)
{
  THTensor *input = luaT_checkudata(L, 2, torch_Tensor);  
  THTensor *gradOutput = luaT_checkudata(L, 3, torch_Tensor);  
  THIntTensor *target = (THIntTensor*)luaT_checkudata(L, 4, "torch.IntTensor");  
  int inputSize = luaT_getfieldcheckint(L, 1, "inputSize");
  long rootId = (long)(luaT_getfieldcheckint(L, 1, "rootId") - 1);
  
  THIntTensor *childParent = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "childParent", "torch.IntTensor");
  THIntTensor *parentChildren = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "parentChildren", "torch.IntTensor");
  
  THTensor *linearGradOutput = luaT_getfieldcheckudata(L, 1, "_linearGradOutput", torch_Tensor);
  THTensor *logsoftOutput = luaT_getfieldcheckudata(L, 1, "_logSoftMaxOutput", torch_Tensor);
  
  THTensor *weight = luaT_getfieldcheckudata(L, 1, "weight", torch_Tensor);
  THTensor *output = luaT_getfieldcheckudata(L, 1, "output", torch_Tensor);
  THTensor *gradInput = luaT_getfieldcheckudata(L, 1, "gradInput", torch_Tensor);
  
  THIntTensor *node;
  THTensor *nodeWeight, *nodeOutput, *nodeGradInter;
  THTensor *nodeGradInput, *nodeGradOutput, *weightTranspose;
  real *gradInput_data, *output_data;

  long i, d;
  long n = 0;
  
  luaL_argcheck(L, input->nDimension == 2, 2, "2D(batch mode) tensor expected");
  luaL_argcheck(L, input->size[1] == inputSize, 2, "invalid input size");
  
  luaL_argcheck(L, gradOutput->nDimension == 1, 2, "1D tensor expected");

  node = THIntTensor_new();
  nodeWeight = THTensor_(new)();
  nodeOutput = THTensor_(new)();
  nodeGradInput = THTensor_(new)();
  nodeGradOutput = THTensor_(new)();
  nodeGradInter = THTensor_(new)();
  weightTranspose = THTensor_(new)();
  
  THTensor_(transpose)(weightTranspose, weight, 0, 1);
  THTensor_(resizeAs)(gradInput, input);
  THTensor_(zero)(gradInput);
  
  for(i = 0; i < input->size[0]; i++)
  {
    long childId = (long)(THIntTensor_get1d(target, i)) - 1;
    real grad = THTensor_(get1d)(gradOutput, i);
    
    THTensor_(select)(nodeGradInput, gradInput, 0, i);
    
    while(1)
    {
      long parentId, parentIdx, childIdx, nChildren;
      /* get next Node in Tree */
      THIntTensor_select(node, childParent, 0, childId);
      parentId = (long)(THIntTensor_get1d(node, 0)) - 1;
      childIdx = (long)(THIntTensor_get1d(node, 1)) - 1;
      
      luaL_argcheck(L, parentId != -2, 2, "Non-root node has no parent in tree.");
      
      THIntTensor_select(node, parentChildren, 0, parentId);
      parentIdx = (long)(THIntTensor_get1d(node, 0)) - 1;
      nChildren = (long)(THIntTensor_get1d(node, 1));
      
      luaL_argcheck(L, logsoftOutput->size[0] >= n+nChildren, 2, \
        "Backward performed on different inputs than last forward");
        
      // we use this to keep intermediate results for later accGradParameters
      THTensor_(resize1d)(linearGradOutput, n+nChildren);
      
      /* CAddTable + Narrow + LogSoftMax */
      THTensor_(narrow)(nodeOutput, logsoftOutput, 0, n, nChildren);
      THTensor_(narrow)(nodeGradInter, linearGradOutput, 0, n, nChildren);
      
      output_data = THTensor_(data)(nodeOutput);
      gradInput_data = THTensor_(data)(nodeGradInter);

      for(d = 0; d < nChildren; d++)
        gradInput_data[d] = -exp(output_data[d])*grad;
      gradInput_data[childIdx] += grad;

  
      /* Linear */
      THTensor_(narrow)(nodeWeight, weightTranspose, 1, parentIdx, nChildren);
      
      THTensor_(addmv)(nodeGradInput, 1, nodeGradInput, 1, nodeWeight, nodeGradInter);
      
      n += nChildren;
      /* Break when root is reached */
      if (parentId == rootId) 
      {
        break;
      }
      childId = parentId;
    }
  }
  
  THIntTensor_free(node);
  THTensor_(free)(nodeWeight);
  THTensor_(free)(nodeOutput);
  THTensor_(free)(nodeGradInput);
  THTensor_(free)(nodeGradInter);
  THTensor_(free)(nodeGradOutput);
  THTensor_(free)(weightTranspose);
  return 1;
}

static int nn_(SoftMaxTree_accGradParameters)(lua_State *L)
{
  THTensor *input = luaT_checkudata(L, 2, torch_Tensor);  
  THTensor *gradOutput = luaT_checkudata(L, 3, torch_Tensor);  
  THIntTensor *target = (THIntTensor*)luaT_checkudata(L, 4, "torch.IntTensor");  
  real scale = luaL_optnumber(L, 5, 1);
  
  int inputSize = luaT_getfieldcheckint(L, 1, "inputSize");
  THIntTensor *childParent = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "childParent", "torch.IntTensor");
  THIntTensor *parentChildren = (THIntTensor*)luaT_getfieldcheckudata(L, 1, "parentChildren", "torch.IntTensor");
  
  THTensor *linearOutput = luaT_getfieldcheckudata(L, 1, "_linearGradOutput", torch_Tensor);;
  
  THTensor *weight = luaT_getfieldcheckudata(L, 1, "weight", torch_Tensor);
  THTensor *bias = luaT_getfieldcheckudata(L, 1, "bias", torch_Tensor);
  THTensor *gradWeight = luaT_getfieldcheckudata(L, 1, "gradWeight", torch_Tensor);
  THTensor *gradBias = luaT_getfieldcheckudata(L, 1, "gradBias", torch_Tensor);
  
  THIntTensor *node;
  THTensor *nodeWeight, *nodeBias, *nodeOutput, *nodeInput, *nodeGradInter, *nodeGradOutput;
  real *input_data, *output_data;

  long i, d;
  long n = 0;
  
  luaL_argcheck(L, input->nDimension == 2, 2, "2D(batch mode) tensor expected");
  luaL_argcheck(L, input->size[1] == inputSize, 2, "invalid input size");
  
  luaL_argcheck(L, gradOutput->nDimension == 1, 2, "1D tensor expected");

  node = THIntTensor_new();
  nodeWeight = THTensor_(new)();
  nodeBias = THTensor_(new)();
  nodeOutput = THTensor_(new)();
  nodeGradOutput = THTensor_(new)();
  nodeInput = THTensor_(new)();
  nodeGradInter = THTensor_(new)();
  
  return 0;
}

static const struct luaL_Reg nn_(SoftMaxTree__) [] = {
  {"SoftMaxTree_updateOutput", nn_(SoftMaxTree_updateOutput)},
  {"SoftMaxTree_updateGradInput", nn_(SoftMaxTree_updateGradInput)},
  {"SoftMaxTree_accGradParameters", nn_(SoftMaxTree_accGradParameters)},
  {NULL, NULL}
};

static void nn_(SoftMaxTree_init)(lua_State *L)
{
  luaT_pushmetatable(L, torch_Tensor);
  luaT_registeratname(L, nn_(SoftMaxTree__), "nn");
  lua_pop(L,1);
}

#endif
