local trailTail = require('trail_tail')

trailTail.new({
})


-- hide armor and elytra when not flying
vanilla_model.ARMOR:setVisible(false)

function events.tick()
   vanilla_model.ELYTRA:setVisible(player:getPose() == 'FALL_FLYING')
end