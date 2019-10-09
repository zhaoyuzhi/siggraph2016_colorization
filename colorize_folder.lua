--[[
   Copyright (C) <2016> <Satoshi Iizuka, Edgar Simo-Serra, Hiroshi Ishikawa>

   This work is licensed under the Creative Commons
   Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy
   of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or
   send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

   Satoshi Iizuka, Waseda University
   iizuka@aoni.waseda.jp, http://hi.cs.waseda.ac.jp/~iizuka/
   Edgar Simo-Serra, Waseda University
   esimo@aoni.waseda.jp, http://hi.cs.waseda.ac.jp/~esimo/
--]]


require 'nn'
require 'nngraph'
require 'image'
require("lfs")

local infolder  = arg[1]
local outfolder = arg[2] or 'output'
local netfile = arg[3] or 'colornet.t7'

local d        = torch.load( netfile )
local datamean = d.mean
local model    = d.model:float()

local function isType(filename) 
   local res = string.match(filename, ".%.jpg$")
   if not res then
         return false
   else
         return true
   end
end

local function pred2rgb( x, data )
   local I = torch.cat( data[1][{{1},{},{}}]:float(),
                        data[1]:clone():float():mul(2):add(-1), 1)
   local O = image.scale( I, x:size(3), x:size(2) )
   local X = image.rgb2lab( image.yuv2rgb( torch.repeatTensor( x, 3, 1, 1 ) ) )
   O    = O*100
   O[1] = X[1]
   O    = image.rgb2yuv( image.lab2rgb( O ) )
   return image.yuv2rgb( torch.cat( x, O[{{2,3},{},{}}], 1 ) )
end

local filenum = 0
for file in lfs.dir(infolder) do
   if file~='.' and file~='..' then
      traverpath = infolder.."/"..file
      attr = lfs.attributes(traverpath)
      if(type(attr)~="table") then
         print('ERROR:'..traverpath..'is not a path')
         save:close()
         return nil
      end
      if(attr.mode == "directory") then
         traver(traverpath)
      elseif attr.mode=="file" and isType(file) then
         outPath = outfolder.."/"..file
         filenum = filenum + 1
         print(filenum)
         local I = image.load( traverpath )
         if I:size(1)==3 then I = image.rgb2y(I) end
         local X2 = image.scale( I, torch.round(I:size(3)/8)*8, torch.round(I:size(2)/8)*8 ):add(-datamean):float()
         local X1 = image.scale( X2, 224, 224 ):float()
         X1 = X1:reshape( 1, X1:size(1), X1:size(2), X1:size(3) )
         X2 = X2:reshape( 1, X2:size(1), X2:size(2), X2:size(3) )
         model.forwardnodes[9].data.module.modules[3].nfeatures = X2:size(3)/8
         model.forwardnodes[9].data.module.modules[4].nfeatures = X2:size(4)/8
         image.save( outPath, pred2rgb( I:float(), model:forward( {X1, X2} ) ) )
      end
   end
end

