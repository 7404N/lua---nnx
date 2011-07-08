
function nnx.test_all()

   xlua.require('lunit',true)
   xlua.require('image',true)

   nnx._test_all_ = nil
   module("nnx._test_all_", lunit.testcase, package.seeall)

   math.randomseed(os.time())

   local precision = 1e-5

   local jac = nnx.jacobian

   function test_SpatialPadding()
      local fanin = math.random(1,3)
      local sizex = math.random(4,16)
      local sizey = math.random(4,16)
      local pad_l = math.random(0,8)
      local pad_r = math.random(0,8)
      local pad_t = math.random(0,8)
      local pad_b = math.random(0,8)
      local module = nn.SpatialPadding(pad_l, pad_r, pad_t, pad_b)
      local input = lab.rand(fanin,sizey,sizex)

      local error = jac.test_jac(module, input)
      assert_equal((error < precision), true, 'error on state: ' .. error)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, 'error in forward after i/o')
      assert_equal(0, berr, 'error in backward after i/o')
   end

   function test_SpatialLinear()
      local fanin = math.random(1,10)
      local fanout = math.random(1,10)
      local sizex = math.random(4,16)
      local sizey = math.random(4,16)
      local module = nn.SpatialLinear(fanin, fanout)
      local input = lab.rand(fanin,sizey,sizex)

      local error = jac.test_jac(module, input)
      assert_equal((error < precision), true, 'error on state: ' .. error)

      local error = jac.test_jac_param(module, input, module.weight, module.gradWeight)
      assert_equal((error < precision), true, 'error on weight: ' .. error)

      local error = jac.test_jac_param(module, input, module.bias, module.gradBias)
      assert_equal((error < precision), true, 'error on bias: ' .. error)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, 'error in forward after i/o')
      assert_equal(0, berr, 'error in backward after i/o')
   end

   function test_SpatialMaxPooling()
      local fanin = math.random(1,10)
      local osizex = math.random(1,4)
      local osizey = math.random(1,4)
      local mx = math.random(2,6)
      local my = math.random(2,6)
      local sizex = osizex*mx
      local sizey = osizey*my
      local module = nn.SpatialMaxPooling(mx,my)
      local input = lab.rand(fanin,sizey,sizex)

      local error = jac.test_jac(module, input)
      assert_equal((error < precision), true, 'error on state: ' .. error)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, 'error in forward after i/o')
      assert_equal(0, berr, 'error in backward after i/o')
   end

   function test_Power()
      local in1 = lab.rand(10,20)
      local mod = nn.Power(2)
      local out = mod:forward(in1)
      local err = out:dist(in1:cmul(in1))
      assert_equal(0, err, torch.typename(mod) .. ' - forward error: ' .. err)

      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local pw = random.uniform()*math.random(1,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Power(pw)

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module,input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Square()
      local in1 = lab.rand(10,20)
      local mod = nn.Square()
      local out = mod:forward(in1)
      local err = out:dist(in1:cmul(in1))
      assert_equal(0, err, torch.typename(mod) .. ' - forward err: ' .. err)

      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Square()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Sqrt()
      local in1 = lab.rand(10,20)
      local mod = nn.Sqrt()
      local out = mod:forward(in1)
      local err = out:dist(in1:sqrt())
      assert_equal(0, err, torch.typename(mod) .. ' - forward err: ' .. err)

      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Sqrt()

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input, 0.1, 2)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Tanh()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Tanh()

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input, 0.1, 2)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_HardShrink()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.HardShrink()

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input, 0.1, 2)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialLogSoftMax()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.SpatialLogSoftMax()

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input, 0.1, 2)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Sigmoid()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Sigmoid()

      local err = jac.test_jac(module, input, 0.1, 2)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input, 0.1, 2)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Threshold()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Threshold(random.uniform(-2,2),random.uniform(-2,2))

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_Abs()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.Abs()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_HardShrink()
      local ini = math.random(5,10)
      local inj = math.random(5,10)
      local ink = math.random(5,10)
      local input = torch.Tensor(ink, inj, ini):zero()

      local module = nn.HardShrink()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialConvolution()
      local from = math.random(1,10)
      local to = math.random(1,10)
      local ki = math.random(1,10)
      local kj = math.random(1,10)
      local si = math.random(1,1)
      local sj = math.random(1,1)
      local ini = math.random(10,20)
      local inj = math.random(10,20)
      local module = nn.SpatialConvolution(from, to, ki, kj, si, sj)
      local input = torch.Tensor(from, inj, ini):zero()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local err = jac.test_jac_param(module, input, module.weight, module.gradWeight)
      assert_equal((err < precision), true, 'error on weight: ' .. err)

      local err = jac.test_jac_param(module, input, module.bias, module.gradBias)
      assert_equal((err < precision), true, 'error on bias: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialConvolutionTable_1()
      local from = math.random(1,10)
      local to = math.random(1,10)
      local ini = math.random(10,20)
      local inj = math.random(10,20)
      local ki = math.random(1,10)
      local kj = math.random(1,10)
      local si = math.random(1,1)
      local sj = math.random(1,1)

      local ct = nn.tables.full(from,to)
      local module = nn.SpatialConvolutionTable(ct, ki, kj, si, sj)
      local input = torch.Tensor(from, inj, ini):zero()
      module:reset()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local err = jac.test_jac_param(module, input, module.weight, module.gradWeight)
      assert_equal((err < precision), true, 'error on weight: ' .. err)

      local err = jac.test_jac_param(module, input, module.bias, module.gradBias)
      assert_equal((err < precision), true, 'error on bias: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialConvolutionTable_2()
      local from = math.random(1,10)
      local to = math.random(1,10)
      local ini = math.random(10,20)
      local inj = math.random(10,20)
      local ki = math.random(1,10)
      local kj = math.random(1,10)
      local si = math.random(1,1)
      local sj = math.random(1,1)

      local ct = nn.tables.oneToOne(from)
      local module = nn.SpatialConvolutionTable(ct, ki, kj, si, sj)
      local input = torch.Tensor(from, inj, ini):zero()
      module:reset()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local err = jac.test_jac_param(module, input, module.weight, module.gradWeight)
      assert_equal((err < precision), true, 'error on weight: ' .. err)

      local err = jac.test_jac_param(module, input, module.bias, module.gradBias)
      assert_equal((err < precision), true, 'error on bias: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialConvolutionTable_3()
      local from = math.random(2,10)
      local to = math.random(1,10)
      local ini = math.random(10,20)
      local inj = math.random(10,20)
      local ki = math.random(1,10)
      local kj = math.random(1,10)
      local si = math.random(1,1)
      local sj = math.random(1,1)

      local ct = nn.tables.random(from,to,from-1)
      local module = nn.SpatialConvolutionTable(ct, ki, kj, si, sj)
      local input = torch.Tensor(from, inj, ini):zero()
      module:reset()

      local err = jac.test_jac(module, input)
      assert_equal((err < precision), true, 'error on state: ' .. err)

      local err = jac.test_jac_param(module, input, module.weight, module.gradWeight)
      assert_equal((err < precision), true, 'error on weight: ' .. err)

      local err = jac.test_jac_param(module, input, module.bias, module.gradBias)
      assert_equal((err < precision), true, 'error on bias: ' .. err)

      local ferr, berr = jac.test_io(module, input)
      assert_equal(0, ferr, torch.typename(module) .. ' - i/o forward err: ' .. ferr)
      assert_equal(0, berr, torch.typename(module) .. ' - i/o backward err: ' .. berr)
   end

   function test_SpatialNormalization_Gaussian2D()
      local inputSize = math.random(11,20)
      local kersize = 9
      local nbfeatures = math.random(5,10)
      local kernel = image.gaussian(kersize)
      local module = nn.SpatialNormalization(nbfeatures,kernel,0.1)
      local input = lab.rand(nbfeatures,inputSize,inputSize)
      local error = jac.test_jac(module, input)
      assert_equal((error < precision), true, torch.typename(module) ..  " w/ 2D Gaussian")
   end

   function test_SpatialNormalization_Gaussian1D()
      local inputSize = math.random(14,20)
      local kersize = 15
      local nbfeatures = math.random(5,10)
      local kernelh = image.gaussian1D(11):resize(11,1)
      local kernelv = kernelh:t()
      local module = nn.SpatialNormalization{kernels={kernelv,kernelh},
                                             nInputPlane=nbfeatures,
                                             threshold=0.1}
      local input = lab.rand(nbfeatures,inputSize,inputSize)
      local error = jac.test_jac(module, input)
      assert_equal((error < precision), true, torch.typename(module) ..  " w/ 1D Gaussian")
   end

   function test_SpatialNormalization_io()
      local inputSize = math.random(11,20)
      local kersize = 7
      local nbfeatures = math.random(2,5)
      local kernel = image.gaussian(kersize)
      local module = nn.SpatialNormalization(nbfeatures,kernel)
      local input = lab.rand(nbfeatures,inputSize,inputSize)
      local error_f, error_b = jac.test_io(module,input)
      assert_equal(0, error_f, torch.typename(module) .. " - i/o forward")
      assert_equal(0, error_b, torch.typename(module) .. " - i/o backward")
   end

   lunit.main()
end
