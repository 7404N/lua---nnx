#ifndef TH_GENERIC_FILE
#define TH_GENERIC_FILE "generic/SpatialLinear.c"
#else

static int nn_(SpatialLinear_updateOutput)(lua_State *L)
{
  // get all params
  THTensor *input = luaT_checkudata(L, 2, torch_(Tensor_id));
  THTensor *bias = luaT_getfieldcheckudata(L, 1, "bias", torch_(Tensor_id));
  THTensor *weight = luaT_getfieldcheckudata(L, 1, "weight", torch_(Tensor_id));
  THTensor *output = luaT_getfieldcheckudata(L, 1, "output", torch_(Tensor_id));

  // dims
  int iwidth = input->size[2];
  int iheight = input->size[1];
  int ichannels = input->size[0];
  int owidth = iwidth;
  int oheight = iheight;
  int ochannels = output->size[0];

  // planes
  THTensor *outputPlane = THTensor_(new)();
  THTensor *inputPlane = THTensor_(new)();

  // process each plane
  int ok,ik;
  for (ok=0; ok<ochannels; ok++) {
    // fill output
    THTensor_(select)(outputPlane, output, 0, ok);
    THTensor_(fill)(outputPlane, THTensor_(get1d)(bias,ok));

    for (ik=0; ik<ichannels; ik++) {
      // get input plane
      THTensor_(select)(inputPlane, input, 0, ik);
      THTensor_(cadd)(outputPlane, THTensor_(get2d)(weight,ok,ik), inputPlane);
    }
  }

  // cleanup
  THTensor_(free)(inputPlane);
  THTensor_(free)(outputPlane);

  return 1;
}

static int nn_(SpatialLinear_updateGradInput)(lua_State *L)
{
  // get all params
  THTensor *input = luaT_checkudata(L, 2, torch_(Tensor_id));
  THTensor *gradOutput = luaT_checkudata(L, 3, torch_(Tensor_id));
  THTensor *gradInput = luaT_getfieldcheckudata(L, 1, "gradInput", torch_(Tensor_id));
  THTensor *weight = luaT_getfieldcheckudata(L, 1, "weight", torch_(Tensor_id));
  THTensor *bias = luaT_getfieldcheckudata(L, 1, "bias", torch_(Tensor_id));
  THTensor *gradWeight = luaT_getfieldcheckudata(L, 1, "gradWeight", torch_(Tensor_id));
  THTensor *gradBias = luaT_getfieldcheckudata(L, 1, "gradBias", torch_(Tensor_id));
  int weightDecay = luaT_getfieldcheckint(L, 1, "weightDecay");

  // dims
  int iwidth = input->size[2];
  int iheight = input->size[1];
  int ichannels = input->size[0];
  int owidth = gradOutput->size[2];
  int oheight = gradOutput->size[1];
  int ochannels = gradOutput->size[0];

  // resize gradInput
  THTensor_(zero)(gradInput);

  // select planes
  THTensor *gradOutput_xy = THTensor_(new)();
  THTensor *gradOutput_y = THTensor_(new)();
  THTensor *gradInput_xy = THTensor_(new)();
  THTensor *gradInput_y = THTensor_(new)();
  THTensor *input_xy = THTensor_(new)();
  THTensor *input_y = THTensor_(new)();

  // transpose weight
  THTensor *weight_t = THTensor_(newTranspose)(weight,0,1);

  // compute gradient
  int x,y;
  for (y=0; y<oheight; y++) {

    // select rows
    THTensor_(select)(gradOutput_y, gradOutput, 1, y);
    THTensor_(select)(gradInput_y, gradInput, 1, y);
    THTensor_(select)(input_y, input, 1, y);

    for (x=0; x<owidth; x++) {

      // (select) cols
      THTensor_(select)(gradOutput_xy, gradOutput_y, 1, x);
      THTensor_(select)(gradInput_xy, gradInput_y, 1, x);
      THTensor_(select)(input_xy, input_y, 1, x);

      // compute dE/dW and dE/dB
      THTensor_(addr)(gradWeight, 1, gradOutput_xy, input_xy);
      THTensor_(cadd)(gradBias, 1, gradOutput_xy);

      // weight decay
      if (weightDecay != 0) {
        THTensor_(cadd)(gradWeight, 1, weight);
      }

      // compute dE/dI
      THTensor_(addmv)(gradInput_xy, 1, 1, weight_t, gradOutput_xy);
    }
  }

  // cleanup
  THTensor_(free)(gradInput_xy);
  THTensor_(free)(gradInput_y);
  THTensor_(free)(gradOutput_xy);
  THTensor_(free)(gradOutput_y);
  THTensor_(free)(input_xy);
  THTensor_(free)(input_y);
  return 1;
}

static const struct luaL_Reg nn_(SpatialLinear__) [] = {
  {"SpatialLinear_updateOutput", nn_(SpatialLinear_updateOutput)},
  {"SpatialLinear_updateGradInput", nn_(SpatialLinear_updateGradInput)},
  {NULL, NULL}
};

static void nn_(SpatialLinear_init)(lua_State *L)
{
  luaT_pushmetaclass(L, torch_(Tensor_id));
  luaT_registeratname(L, nn_(SpatialLinear__), "nn");
  lua_pop(L,1);
}

#endif
