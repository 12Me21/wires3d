name = "3d_wires:lcd"
mesecon.register_node(name, {
	description = "LCD Pixel",
},{
	groups = {cracky = 2, mesecon = 2},
	tiles = {"3dwires_lcd_off.png"},
	mesecons = {effector = {
		rules = wires.all_connections,
		action_on = function (pos, node)
			minetest.swap_node(pos, {name = name.."_on", param2 = node.param2})
		end,
	}},
},{
	groups = {cracky = 2, not_in_creative_inventory = 1, mesecon = 2},
	tiles = {"3dwires_lcd_on.png"},
	mesecons = {effector = {
		rules = wires.all_connections,
		action_off = function (pos, node)
			minetest.swap_node(pos, {name = name.."_off", param2 = node.param2})
		end,
	}},
})