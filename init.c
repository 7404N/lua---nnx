#include "TH.h"
#include "luaT.h"

#define torch_(NAME) TH_CONCAT_3(torch_, Real, NAME)
#define torch_string_(NAME) TH_CONCAT_STRING_3(torch., Real, NAME)
#define nn_(NAME) TH_CONCAT_3(nn_, Real, NAME)

static const void* torch_FloatTensor_id = NULL;
static const void* torch_DoubleTensor_id = NULL;

#include "generic/Abs.c"
#include "THGenerateFloatTypes.h"

#include "generic/HardShrink.c"
#include "THGenerateFloatTypes.h"

#include "generic/SpatialLinear.c"
#include "THGenerateFloatTypes.h"

DLL_EXPORT int luaopen_libnnx(lua_State *L)
{
  torch_FloatTensor_id = luaT_checktypename2id(L, "torch.FloatTensor");
  torch_DoubleTensor_id = luaT_checktypename2id(L, "torch.DoubleTensor");

  nn_FloatSpatialLinear_init(L);
  nn_FloatHardShrink_init(L);
  nn_FloatAbs_init(L);

  nn_DoubleSpatialLinear_init(L);
  nn_DoubleHardShrink_init(L);
  nn_DoubleAbs_init(L);

  return 1;
}
