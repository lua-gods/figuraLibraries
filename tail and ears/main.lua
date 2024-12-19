-- not releated to tail and ears physics
-- check example.lua for examples

-- use custom model for body and head to remove things (ears and tail) from Ears Mod
vanilla_model.BODY:visible(false)
vanilla_model.HEAD:visible(false)
models.player:setPrimaryTexture('SKIN')