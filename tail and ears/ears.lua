-- config --
local config = {
    leftEar = models.example.Head.leftEar, -- model part of left ear
    rightEar = models.example.Head.rightEar, -- model part of right ear

    velocityStrength = 1,

    extraAngle = 15, -- rotates ears by this angle when crouching
    useExtraAngle = {}, -- if any of variables in this table is true extraAngle will be used even when not crouching

    addAngle = {}, -- adds angle to ear rotation
}

-- code --
if not config.leftEar then
    error("no model part for left ear found")
end
if not config.rightEar then
    error("no model part for right ear found")
end

local defaultLeftEarRot = config.leftEar:getRot()
local defaultRightEarRot = config.rightEar:getRot()
local rot = vec(0, 0, 0, 0)
local oldRot = rot
local vel = vec(0, 0, 0, 0)
local oldPlayerRot = nil

function events.tick()
    -- set oldRot
    oldRot = rot
    -- set target rotation
    local targetRot = 0
    if player:getPose() == "CROUCHING" then
        targetRot = 15
    else
        for _, v in pairs(config.useExtraAngle) do
            if v then
                targetRot = config.extraAngle
                break
            end
        end
    end
    for _, v in pairs(config.addAngle) do
        targetRot = targetRot + v
    end
    -- player velocity
    local playerRot = player:getRot()
    if not oldPlayerRot then
        oldPlayerRot = playerRot
    end
    local playerRotVel = (playerRot - oldPlayerRot) * 0.75 * config.velocityStrength
    oldPlayerRot = playerRot
    local playerVel = player:getVelocity()
    playerVel = vectors.rotateAroundAxis(playerRot.y, playerVel, vec(0, 1, 0))
    playerVel = vectors.rotateAroundAxis(-playerRot.x, playerVel, vec(1, 0, 0))
    playerVel = playerVel * config.velocityStrength * 40
    -- update velocity and rotation
    vel = vel * 0.6 + (vec(0, 0, 0, targetRot) - rot) * 0.2
    rot = rot + vel
    rot.x = rot.x + math.clamp(playerVel.z + playerRotVel.x, -14, 14)
    rot.z = rot.z + math.clamp(-playerVel.x, -6, 6)
end

function events.render(delta)
    local currentRot = math.lerp(oldRot, rot, delta)
    config.leftEar:setRot(defaultLeftEarRot + currentRot.xyz + currentRot.__w)
    config.rightEar:setRot(defaultRightEarRot + currentRot.x_z - currentRot._yw)
end

return config -- by Auria <3
