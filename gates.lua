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

local gates = {
	["and_gate"]     = {name = "And Gate"             , operation = function(a,b) return a and b end     , inputs = 2},
	["and_not_gate"] = {name = "Comparator"    , operation = function(a,b) return a and not b end , inputs = 2}, -- A > B
	["xor_gate"]     = {name = "Not Equal (Xor) Gate" , operation = function(a,b) return a ~= b end      , inputs = 2}, -- A != B
	["or_gate"]      = {name = "Or Gate"              , operation = function(a,b) return a or b end      , inputs = 2},
	["nor_gate"]     = {name = "Nor Gate"             , operation = function(a,b) return not(a or b) end , inputs = 2},
	["nxor_gate"]    = {name = "Equal (Xnor) Gate"    , operation = function(a,b) return a == b end      , inputs = 2}, -- A == B
	["or_not_gate"]  = {name = "Inverted Comparator", operation = function(a,b) return a or not b end  , inputs = 2}, -- A >= B
	["nand_gate"]    = {name = "Nand Gate"            , operation = function(a,b) return not(a and b) end, inputs = 2},
	
	["diode"]        = {name = "Diode"                , operation = function(a) return a end             , inputs = 1},
	["not_gate"]     = {name = "Not Gate"             , operation = function(a) return not a end         , inputs = 1},
}

local gate_output_rules = make_rule_rotator({
	{x=0, y=-1, z=0},
})

local gate_input_rules = {
	[1] = make_rule_rotator({
		{x=0, y=1, z=0},
	}),
	[2] = make_rule_rotator({
		{x=-1, y=0, z=0, name="1"},
		{x= 1, y=0, z=0, name="2"},
	}),
}

local function make_gate_updater(gate_function, off_state, on_state, inputs)
	if inputs == 1 then
		return function(pos, node, link, newstate)
			if mesecon.do_overheat(pos) then
				minetest.remove_node(pos)
				mesecon.receptor_off(pos, gate_output_rules(node))
				local def = minetest.registered_nodes[node.name]
				minetest.add_item(pos, def.drop)
			elseif gate_function(newstate == "on") then
				minetest.swap_node(pos, {name = on_state, param2 = node.param2})
				mesecon.receptor_on(pos, gate_output_rules(node))
			else
				minetest.swap_node(pos, {name = off_state, param2 = node.param2})
				mesecon.receptor_off(pos, gate_output_rules(node))
			end
		end
	else
		return function(pos, node, link, newstate)
			local meta = minetest.get_meta(pos)
			meta:set_int(link.name, newstate == "on" and 1 or 0)
			if mesecon.do_overheat(pos) then
				minetest.remove_node(pos)
				mesecon.receptor_off(pos, gate_output_rules(node))
				local def = minetest.registered_nodes[node.name]
				minetest.add_item(pos, def.drop)			
			elseif gate_function(meta:get_int("1") == 1, meta:get_int("2") == 1) then
				minetest.swap_node(pos, {name = on_state, param2 = node.param2})
				mesecon.receptor_on(pos, gate_output_rules(node))			
			else
				minetest.swap_node(pos, {name = off_state, param2 = node.param2})
				mesecon.receptor_off(pos, gate_output_rules(node))
			end
		end
	end
end

local gate_side_texture_off = "mesecons_wire_off.png^3dwires_gate_center.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)"

local gate_nodeboxes = {
	[1] = {
		type = "fixed",
		fixed = {
			{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
			{-wire_radius, -0.5, -wire_radius, wire_radius, 0.5, wire_radius},
		}
	},
	[2] = {
		type = "fixed",
		fixed = {
			{-diode_radius, -diode_radius, -diode_radius, diode_radius, diode_radius, diode_radius},
			{-0.5, -wire_radius, -wire_radius, 0.5, wire_radius, wire_radius},
			{-wire_radius, -0.5, -wire_radius, wire_radius, 0, wire_radius},
		}
	},
}
local function make_gate_tiles(filename, inputs)
	if inputs==1 then
		return {
			"3dwires_gate_center.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)",
			"3dwires_gate_center.png^3dwires_diode_paint_bottom.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_side.png^3dwires_"..filename.."_symbol.png",
		}
	else
		return {
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_"..filename.."_symbol.png",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_bottom.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_side.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_side.png^(mesecons_wire_off.png^[mask:3dwires_wire_end_mask.png)",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_side.png^(3dwires_"..filename.."_symbol.png^[transformR180)",
			"mesecons_wire_off.png^3dwires_gate_center.png^3dwires_diode_paint_side.png^3dwires_"..filename.."_symbol.png",
		}
	end
end

local function make_on_tiles(off_tiles)
	local on_tiles = {}
	for i in ipairs(off_tiles) do
		on_tiles[i] = off_tiles[i]:gsub("_off","_on")
	end
	return on_tiles
end

-- Register on/off forms of a 2-input gate called <name> using <gate_function>
local function define_gate(name, description, gate_function, inputs)
	local basename = "3d_wires:"..name
	local updater = make_gate_updater(gate_function, basename.."_off", basename.."_on", inputs)
	local tiles = make_gate_tiles(name, inputs)
	mesecon.register_node(basename, {
		description = "3D " .. description,
		paramtype = "light",
		paramtype2 = "facedir",
		on_place = place_rotated.log,
		drawtype = "nodebox",
		on_rotate = wires.on_rotate,
		node_box = gate_nodeboxes[inputs],
		walkable = false,
		climbable = true,
		onstate = basename.."_on",
		offstate = basename.."_off",
		node_placement_prediction = "",
	},{
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, overheat = 1},
		tiles = tiles,
		mesecons = {receptor = {
			state = "off",
			rules = gate_output_rules,
		}, effector = {
			rules = gate_input_rules[inputs],
			action_change = updater
		}}
	},{
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, overheat = 1},
		tiles = make_on_tiles(tiles),
		mesecons = {receptor = {
			state = "on",
			rules = gate_output_rules,
		}, effector = {
			rules = gate_input_rules[inputs],
			action_change = updater
		}}
	})
end

for name, gate in pairs(gates) do
	define_gate(name, gate.name, gate.operation, gate.inputs)
end

-- idea: make gate inputs texture independant from output
-- this means 8 nodes/gate rather than 2...