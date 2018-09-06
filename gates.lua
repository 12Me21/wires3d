local wire_radius = 2/16
local diode_radius = 4/16

local function rotate_rule(rule, axis, rotation)
	for i = 1, rotation do
		rule.x, rule.z = -rule.z, rule.x
	end
	
	-- Y+ (no change)
	if axis == 0 then 
	-- Z+
	elseif axis == 1 then
		rule.y, rule.z = -rule.z, rule.y
	-- z-
	elseif axis == 2 then
		rule.y, rule.z = rule.z, -rule.y
	-- X+
	elseif axis == 3 then 
		rule.y, rule.x = -rule.x, rule.y
	-- x-
	elseif axis == 4 then
		rule.y, rule.x = rule.x, -rule.y
	-- y-
	elseif axis == 5 then
		-- Note: I checked, and the game rotates the node 180 degrees around the Z axis here.
		rule.y, rule.x = -rule.y, -rule.x
	end
	return rule
end

-- Generates a function that outputs the rules, rotated to match the node
local function make_rule_rotator(rules)
	return function(node)
		local rotation = node.param2 % 4
		local axis = (node.param2 - rotation) / 4
		local new_rules = {}
		for i, rule in ipairs(rules) do
			new_rules[i] = rotate_rule(table.copy(rule),axis,rotation)
		end
		return new_rules
	end
end

local diode_output_rules = make_rule_rotator({
	{x=0,y=-1,z=0}
})

local function set_gate(pos, node, state)
	local def = minetest.registered_nodes[node.name]
	if state then
		minetest.swap_node(pos, {name = def.onstate, param2=node.param2})
		mesecon.receptor_on(pos, diode_output_rules(node))
	else
		minetest.swap_node(pos, {name = def.offstate, param2=node.param2})
		mesecon.receptor_off(pos, diode_output_rules(node))
	end
end

local diode_input_rules = make_rule_rotator({
	{x=0,y=1,z=0},
})

local function update_diode(pos, node, link, newstate)
	set_gate(pos, node, newstate == "on")
end

name = "3d_wires:diode"
mesecon.register_node(name, {
	description = "3D Diode",
	paramtype = "light",
	paramtype2 = "facedir",
	on_place = place_rotated.log,
	drawtype = "nodebox",
	on_rotate = wires.on_rotate,
	node_box = {
		type = "fixed",
		fixed = {
			{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
			{-wire_radius, -0.5, -wire_radius, wire_radius, 0.5, wire_radius},
		}
	},
	walkable = false,
	climbable = true,
	onstate = name.."_on",
	offstate = name.."_off",
	node_placement_prediction = "", -- let server update node
},{
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	tiles = {"3dwires_diode_top.png","3dwires_diode_bottom.png","3dwires_diode_side.png"},
	mesecons = {receptor = {
		state = "off",
		rules = diode_output_rules,
	}, effector = {
		rules = diode_input_rules,
		action_change = update_diode
	}}
},{
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
	tiles = {"3dwires_diode_top.png^[brighten","3dwires_diode_bottom.png^[brighten","3dwires_diode_side.png^[brighten"},
	mesecons = {receptor = {
		state = "on",
		rules = diode_output_rules,
	}, effector = {
		rules = diode_input_rules,
		action_change = update_diode
	}}
})

local function update_not_gate(pos, node, link, newstate)
	if mesecon.do_overheat(pos) then
		local def = minetest.registered_nodes[node.name]
		minetest.remove_node(pos)
		mesecon.receptor_off(pos, diode_output_rules(node))
		minetest.add_item(pos, def.drop)
	else
		set_gate(pos, node, newstate == "off")
	end
end

name = "3d_wires:not_gate"
mesecon.register_node(name, {
	description = "3D Not Gate",
	paramtype = "light",
	paramtype2 = "facedir",
	on_place = place_rotated.log,
	drawtype = "nodebox",
	on_rotate = wires.on_rotate,
	node_box = {
		type = "fixed",
		fixed = {
			{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
			{-wire_radius, -0.5, -wire_radius, wire_radius, 0.5, wire_radius},
		}
	},
	walkable = false,
	climbable = true,
	onstate = name.."_on",
	offstate = name.."_off",
	node_placement_prediction = "", -- let server update node
},{
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, overheat = 1},
	tiles = {"3dwires_diode_top.png","3dwires_diode_bottom.png","3dwires_diode_side.png^3dwires_gate_nor.png"},
	mesecons = {receptor = {
		state = "off",
		rules = diode_output_rules,
	}, effector = {
		rules = diode_input_rules,
		action_change = update_not_gate
	}}
},{
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, overheat = 1},
	tiles = {"3dwires_diode_top.png^[brighten","3dwires_diode_bottom.png^[brighten","3dwires_diode_side.png^3dwires_gate_nor.png^[brighten"},
	mesecons = {receptor = {
		state = "on",
		rules = diode_output_rules,
	}, effector = {
		rules = diode_input_rules,
		action_change = update_not_gate
	}}
})

local gates = {
	["And"] = function(a,b) return a and b end,
	["And Not"] = function(a,b) return a and not b end, -- idk
	["Xor"] = function(a,b) return a ~= b end,
	["Or"] = function(a,b) return a or b end,
	["Nor"] = function(a,b) return not(a or b) end,
	["Nxor"] = function(a,b) return a == b end,
	["Or Not"] = function(a,b) return a or not b end, -- "implies"
	["Nand"] = function(a,b) return not(a and b) end,
}

local gate_nodebox = {
	{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
	{-0.5, -wire_radius, -wire_radius, 0.5, wire_radius, wire_radius},
	{-wire_radius, -0.5, -wire_radius, wire_radius, 0, wire_radius},
}

local gate_output_rules = make_rule_rotator({
	{x=0,y=-1,z=0}
})

local gate_input_rules = make_rule_rotator({
	{x=-1,y=0,z=0,name="1"},
	{x= 1,y=0,z=0,name="2"},
})

local function make_gate_updater(gate_function, off_state, on_state)
	return function(pos, node, link, newstate)
		local meta = minetest.get_meta(pos)
		meta:set_int(link.name, newstate == "on" and 1 or 0)
		if mesecon.do_overheat(pos) then
			local def = minetest.registered_nodes[node.name]
			minetest.remove_node(pos)
			mesecon.receptor_off(pos, diode_output_rules(node))
			minetest.add_item(pos, def.drop)			
		elseif gate_function(meta:get_int("1") == 1, meta:get_int("2") == 1) then
			minetest.swap_node(pos, {name = on_state, param2 = node.param2})
			mesecon.receptor_on(pos, diode_output_rules(node))			
		else
			minetest.swap_node(pos, {name = off_state, param2 = node.param2})
			mesecon.receptor_off(pos, diode_output_rules(node))
		end
	end
end

local function define_gate(name, gate_function)
	local filename = name:lower():gsub(" ","_") -- name converted to lowercase and with underscores
	local basename = "3d_wires:"..filename.."gate"
	local updater = make_gate_updater(gate_function, basename.."_off", basename.."_on")
	mesecon.register_node(basename, {
		description = "3D "..name.." Gate",
		paramtype = "light",
		paramtype2 = "facedir",
		on_place = place_rotated.log,
		drawtype = "nodebox",
		on_rotate = wires.on_rotate,
		node_box = {
			type = "fixed",
			fixed = {
				{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
				{-0.5, -wire_radius, -wire_radius, 0.5, wire_radius, wire_radius},
				{-wire_radius, -0.5, -wire_radius, wire_radius, 0, wire_radius},
			}
		},
		walkable = false,
		climbable = true,
		onstate = basename.."_on",
		offstate = basename.."_off",
		node_placement_prediction = "", -- let server update node
	},{
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, overheat = 1},
		tiles = {
			"3dwires_gate_center.png^3dwires_gate_"..filename..".png",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png",
			"3dwires_gate_center.png^(3dwires_gate_"..filename..".png^[transformR180)",
			"3dwires_gate_center.png^3dwires_gate_"..filename..".png",
		},
		mesecons = {receptor = {
			state = "off",
			rules = gate_output_rules,
		}, effector = {
			rules = gate_input_rules,
			action_change = updater
		}}
	},{
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, overheat = 1},
		tiles = {
			"3dwires_gate_center.png^3dwires_gate_"..filename..".png^[brighten",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png^[brighten",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png^[brighten",
			"3dwires_gate_center.png^3dwires_gate_wire_end.png^[brighten",
			"3dwires_gate_center.png^(3dwires_gate_"..filename..".png^[transformR180)^[brighten",
			"3dwires_gate_center.png^3dwires_gate_"..filename..".png^[brighten",
		},
		mesecons = {receptor = {
			state = "on",
			rules = gate_output_rules,
		}, effector = {
			rules = gate_input_rules,
			action_change = updater
		}}
	})
end

for name, gate_function in pairs(gates) do
	define_gate(name, gate_function)
end


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


-- 0001 - a and b
-- and gate

-- 0010 - b and not(a)
-- and gate + not gate

-- 0110 - a xor b
-- xor gate

-- 0111 - a or b
-- diode + diode

-- 1000 - not(a or b)
-- not gate + or gate

-- 1001 - not(a xor b)
-- not gate + xor gate

-- 1011 - b or (not a)
-- or gate + not gate

-- 1110 - not(a and b)
-- not gate + and gate

-- Base gates:
-- not gate = mese cystal + silicon + wire
--  m
-- wsw
--  m

-- diode = silicon + wire
-- wsw

-- and gate = silicon + wire (+)
-- ws
-- sss
--  sw

-- xor gate = silicon + wire (x)
-- s s
-- wsw
-- s s

-- level 0.5 gate:
-- or gate = diode + diode

-- level 1 gates:
-- nand gate = not + and
-- nor gate = not + or
-- nxor gate = not + xor
-- andn gate = and + not
-- orn gate = or + not
