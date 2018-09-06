wires = {}
-- Hmm...
-- Maybe rename mod to "wires_3d" so the name doesn't begin with a number

-- Official axis/face/direction ordering to be used whenever possible
-- x- y- z- X+ Y+ Z+
local directions = {
	{vector = {x =-1, y = 0, z = 0}, name = "left"  },
	{vector = {x = 0, y =-1, z = 0}, name = "bottom"},
	{vector = {x = 0, y = 0, z =-1}, name = "front" },
	{vector = {x = 1, y = 0, z = 0}, name = "right" },
	{vector = {x = 0, y = 1, z = 0}, name = "top"   },
	{vector = {x = 0, y = 0, z = 1}, name = "back"  },
}
for i, direction in ipairs(directions) do
	direction.opposite = directions[(i-1 + 3) % 6 +1]
end
-- Convert a vector to a direction index
local function vector_to_direction(v)
	for i, direction in ipairs(directions) do
		if vector.equals(v,direction.vector) then return i end
	end
end

-- Everything in minetest uses a different order for the axes/faces
-- For node textures, it's [Y+ y- X+ x- Z+ z-] so we have to convert to this when specifying tiles.
local direction_to_texture_index = {4, 2, 6, 3, 1, 5}

--iterator
--index, mask
function bits(field)
	local i = 1
	local bit = 1
	return function()
		if field == 0 then return end
		while field % 2 == 0 do
			field = field / 2
			i = i + 1
			bit = bit * 2
		end
		return i, bit
	end
end

-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

-- Test whether bit number <bit> is set in <x>
local function check_bit(x, bit)
	return math.floor(x / 2^bit) % 2 == 1
	-- return (x >> bit & 1) == 1
end

-- Check whether the mesecon at <pos> has <direction> in its input/output rules
function check_connect(pos, direction)
	local node = minetest.get_node(pos)
	local rules = mesecon.get_any_inputrules(node)
	if rules then
		for i,rule in ipairs(mesecon.flattenrules(rules)) do -- do I need to flatten rules here?
			if vector.equals(rule,direction) then return true end
		end
	end
	rules = mesecon.get_any_outputrules(node)
	if rules then
		for i,rule in ipairs(mesecon.flattenrules(rules)) do
			if vector.equals(rule,direction) then return true end
		end
	end
end

-- Detect which sides of a node at <pos> should connect to surrounding mesecons
-- Returns a 6 bit number
function get_connections(pos)
	local field = 0
	for i = 0, 5 do
		if check_connect(
			vector.add(pos, directions[i+1].vector), -- Neighboring position
			directions[i+1].opposite.vector -- Vector pointing from neighbor to center node
		) then
			field = field + 2^i
		end
	end
	return field
end

-- If there's a wire at <pos>, replace it with the correct variant to connect with surrounding mesecons.
local function update_connections(pos)
	local node = minetest.get_node_or_nil(pos)
	if node and node.name:find("^3d_wires:wire_") then
		minetest.set_node(pos,{
			-- Replace the number in the wire name with new value
			name = node.name:gsub("_%d+", "_"..get_connections(pos), 1) --bad
		})
	end
end

-- Autoconnect function
-- Calls update_connections at <pos> and the 6 surrounding locations
-- This is called whenever a node is placed or removed (basically)
mesecon.register_autoconnect_hook("3d_wire", function(pos, node)
	update_connections(pos)
	for _, direction in ipairs(directions) do
		update_connections(vector.add(pos, direction.vector))
	end
end)

-- This is used when a player tries to modify a wire using the wire cutters or insulation.
-- TODO: skip updating mesecons when rules don't change (check wire number when swapping insulation)
local function modify_wire(pos, placer, new_node, skip_update)
	-- Check permissions
	local player_name = placer:get_player_name()
	if minetest.is_protected(pos, player_name) then
		minetest.record_protection_violation(pos, player_name)
	else
		if skip_update then
			minetest.set_node(pos,new_node)
		else
			-- Place node and update mesecons
			mesecon.on_dignode(pos,minetest.get_node(pos))
			minetest.set_node(pos,new_node) -- Actually place new node
			mesecon.on_placenode(pos,new_node)
			-- Update surrounding nodes (I feel like there is a better way to do this...)
			for _,direction in ipairs(directions) do
				local pos2 = vector.add(pos, direction.vector)
				mesecon.on_placenode(pos2,minetest.get_node(pos2))
			end
		end
	end
end

-- This is for the on_rotate function which is called by the screwdriver before trying to rotate the node
-- I'm using it to update the connections when rotating a logic gate.
-- Ideally there would be an after_rotate, but instead I just place the new node manually...
function wires.on_rotate(pos, node, user, mode, new_param2)
	node.param2 = new_param2
	modify_wire(pos, user, node)
	return true
end

-- Convert the selected nodebox id of a wire into the direction that nodebox is facing
-- The get_point function returns the nodebox id that is selected
-- However, this id depends on what other nodeboxes are defined for that node
-- So this converts it into a standard direction id (1 to 6) or 0 for the center
local function pointed_box_to_direction(box_id, connections)
	if box_id==1 then return 0 end
	for i = 0, 5 do
		if check_bit(connections,i) then
			if box_id == 2 then
				return i+1
			end
			box_id = box_id - 1
		end
	end
end

-- Take item if player is not in creative mode
local function take_unless_creative(player, itemstack)
	if creative and not creative.is_enabled_for(player:get_player_name()) then
		itemstack:take_item()
	end
end

-- =============================================================================
-- # ITEM FUNCTIONS ############################################################
-- =============================================================================
-- (For on_place, on_use, etc.)

-- Remove insulation
-- on_use
local function remove_insulation(itemstack, placer, pointed_thing)
	local pos = pointed_thing.under
	if pos then
		local under = minetest.get_node_or_nil(pos)
		if under then
			local state = under.name:match("^3d_wires:insulated_wire_(.*)")
			if state then
				modify_wire(pos, placer, {name = "3d_wires:wire_"..state})
				placer:get_inventory():add_item("main", minetest.itemstring_with_palette("3d_wires:insulation", under.param2))
				return itemstack
			end
		end
	end
end

-- Add insulation to a wire, or replace existing insulation
-- on_place
-- TODO: complain about how creative mode doesn't have a system for handling custom drops
local function add_insulation(itemstack, placer, pointed_thing)
	local pos = pointed_thing.under
	if pos then
		local under = minetest.get_node_or_nil(pos)
		if under then
			local type, state = under.name:match("^3d_wires:(.*)wire_(.*)")
			local color = itemstack:get_meta():get_int("palette_index")
			-- Add insulation to bare wires
			if type == "" then
				modify_wire(pos, placer, {name = "3d_wires:insulated_wire_"..state, param2 = color}, true)
				take_unless_creative(placer, itemstack)
				return itemstack
			-- Replace insulation on insulated wires
			elseif type == "insulated_" then
				modify_wire(pos, placer, {name = "3d_wires:insulated_wire_"..state, param2 = color}, true)
				take_unless_creative(placer, itemstack)
				placer:get_inventory():add_item("main", minetest.itemstring_with_palette("3d_wires:insulation", under.param2))
				return itemstack
			end
		end
	end
	-- Otherwise, call the default function to allow normal interaction with other nodes
	return minetest.item_place(itemstack, placer, pointed_thing)
end

-- Remove a connection from an insulated wire
-- on_use
local function cut_wire(itemstack, placer, pointed_thing)
	if pointed_thing.under then
		local under = minetest.get_node_or_nil(pointed_thing.under)
		if under then
			local field, state = under.name:match("^3d_wires:insulated_wire_([0-9]+)(.*)")
			if field then
				local _, _, box = place_rotated.get_point(placer)
				local arm = pointed_box_to_direction(box, field)-1
				if arm ~= -1 and check_bit(field, arm) then
					modify_wire(pointed_thing.under, placer, {name="3d_wires:insulated_wire_"..(field-2^arm)..state, param2 = under.param2})
				end
			end
		end
	end
end

-- Add a connection to an insulated wire
-- on_place
local function splice_wire(itemstack,placer,pointed_thing)
	if pointed_thing.under then
		local under=minetest.get_node(pointed_thing.under)
		if under then
			-- First, try to add a connection to the node that was clicked
			local field,state = under.name:match("^3d_wires:insulated_wire_([0-9]+)(.*)")
			if field then
				local normal, point, box = place_rotated.get_point(placer)
				local arm = pointed_box_to_direction(box, field)
				if arm == 0 then
					local face = vector_to_direction(normal)
					if face and not check_bit(field, face-1) then
						modify_wire(pointed_thing.under,placer,{name="3d_wires:insulated_wire_"..(field+2^(face-1))..state, param2 = under.param2})
						return
					end
				end
			end
			-- If that didn't work, also try adding a connection to the `above` node.
			-- This is so you can click on the node *behind* a wire to modify the side of the wire which is facing away from you
			local above=minetest.get_node(pointed_thing.above)
			if above then
				local field,state = above.name:match("^3d_wires:insulated_wire_([0-9]+)(.*)")
				if field then
					local normal, point, box = place_rotated.get_point(placer)
					local face = vector_to_direction(vector.multiply(normal,-1))
					if face and not check_bit(field, face-1) then
						modify_wire(pointed_thing.above,placer,{name="3d_wires:insulated_wire_"..(field+2^(face-1))..state, param2 = above.param2})
						return
					end
				end
			end
		end
	end
	return minetest.item_place(itemstack, placer, pointed_thing)
end

-- =============================================================================
-- #############################################################################
-- =============================================================================

-- Make a tiles list, given a 6 bit value
local function make_texture_list(bits, on, off)
	local list = {off, off, off, off, off, off}
	for i = 0, 5 do
		if check_bit(bits, i) then
			list[direction_to_texture_index[i+1]] = on
		end
	end
	return list
end

-- Generate wire node boxes and connection rules for a given connection state
local function generate_wire_info(full, full_insulated, bits)
	local node_box = {type = "fixed", fixed = {full.fixed}}
	local insulated_node_box = {type = "fixed", fixed = {full_insulated.fixed}}
	local mesecon_rules = {}
	for i = 0, 5 do
		if check_bit(bits, i) then
			local name = directions[i+1].name
			table.insert(node_box.fixed, full["connect_"..name])
			table.insert(insulated_node_box.fixed, full_insulated["connect_"..name])
			table.insert(mesecon_rules, directions[i+1].vector)
		end
	end
	return node_box, insulated_node_box, mesecon_rules
end

local wire_radius = 2/16
local insulated_wire_radius = 3/16

-- Originally the non-insulated wires used connected nodeboxes, but this ended up being too limited
-- I switched to having a different node for each connection state,
-- so now this is just used as a lookup table when generating the nodeboxes
local function make_wire_nodebox(size)
	return {
		type = "connected",
		fixed          = {-size, -size, -size, size,  size, size},
		connect_left   = {-0.5,  -size, -size, size,  size, size}, -- x-
		connect_right  = {-size, -size, -size, 0.5,   size, size}, -- x+
		connect_bottom = {-size, -0.5,  -size, size,  size, size}, -- y-
		connect_top    = {-size, -size, -size, size,  0.5,  size}, -- y+
		connect_front  = {-size, -size, -0.5,  size,  size, size}, -- z-
		connect_back   = {-size, -size,  size, size,  size, 0.5 }, -- z+
	}
end

--create wires
local all_connections = {}
for i, direction in ipairs(directions) do
	all_connections[i] = direction.vector
end
wires.all_connections = all_connections

local full_box = make_wire_nodebox(wire_radius)
local full_insulated = make_wire_nodebox(insulated_wire_radius)
for i = 0, 2^6-1 do
	local node_box, insulated_node_box, mesecon_rules = generate_wire_info(full_box, full_insulated, i)
	--insulated wires
	local name = "3d_wires:insulated_wire_"..i
	local wire_groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2}
	if i ~= 0 then wire_groups.not_in_creative_inventory = 1 end
	mesecon.register_node(name, {
		drop = {
			items = {
				{items = {"3d_wires:insulation"}, inherit_color = true},
				{items = {"3d_wires:wire_0_off"}},
			}
		},
		description = "Insulated 3D Wire",
		paramtype = "light",
		paramtype2 = "color",
		drawtype = "nodebox",
		node_box = insulated_node_box,
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
		walkable = false,
		climbable = true,
		palette = "3dwires_palette.png",
	},{
		tiles = {"3dwires_wool.png"},
		overlay_tiles = make_texture_list(i, {name = "placerotated_wire_end.png", color = "white"}, ""),
		mesecons = {conductor = {
			state = "off",
			onstate = name.."_on",
			rules = mesecon_rules,
		}}
	},{
		tiles = {"3dwires_wool.png^[brighten"},
		overlay_tiles = make_texture_list(i, {name = "placerotated_wire_end.png^[brighten", color = "white"}, ""),
		mesecons = {conductor = {
			state = "on",
			offstate = name.."_off",
			rules = mesecon_rules,
		}}
	})
	--normal wires
	local name = "3d_wires:wire_"..i
	mesecon.register_node(name, {
		drop = "3d_wires:wire_0_off",
		description = "3D Wire",
		paramtype = "light",
		drawtype = "nodebox",
		node_box = node_box,
		walkable = false,
		climbable = true,
		node_placement_prediction = "", -- let server update node
	},{
		groups = wire_groups,
		tiles = {"default_mese_block.png"},
		mesecons = {conductor = {
			state = "off",
			onstate = name.."_on",
			rules = all_connections,
		}}
	},{
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
		tiles = {"default_mese_block.png^[brighten"},
		mesecons = {conductor = {
			state = "on",
			offstate = name.."_off",
			rules = all_connections,
		}}
	})
end

-- =========
-- # ITEMS #
-- =========

-- Insulation for wires
-- Place = add insulation
-- Punch = remove insulation 
minetest.register_craftitem("3d_wires:insulation", {
	description = "Insulation",
	inventory_image = "3dwires_insulation.png",
	on_place = add_insulation,
	on_use = remove_insulation,
	palette = "3dwires_palette.png",
})

-- Tool for modifying the shape of insulated wires
-- Place = add connection
-- Punch = remove connection
minetest.register_tool("3d_wires:wire_cutters", {
	description = "Wire Cutters",
	inventory_image = "placerotated_wire_cutters.png",
	on_place = splice_wire,
	on_use = cut_wire,
})

-- ===========
-- # RECIPES #
-- ===========

minetest.register_craft({
	output = "3d_wires:wire_cutters",
	recipe = {
		{"default:steel_ingot",""                   ,"default:steel_ingot"},
		{""                   ,"default:steel_ingot",""                   },
		{"group:stick"        ,""                   ,"group:stick"        },
	},
})

minetest.register_craft({
	output = "3d_wires:diode_off",
	recipe = {
		{"3d_wires:wire_0_off","mesecons_materials:silicon","3d_wires:wire_0_off"},
	},
})

dofile(minetest.get_modpath("3d_wires").."/gates.lua")

--make not gate use yellow instead of red
--maybe use yellow to signify inverted input/output
--put output marker on all gates

--idea: use param2 coloring to have colored insulated wires!!!!
--use colored wool on wires to put insulation maybe
--ok using wool is total crap I'll have to define a custom item for this :(

--controls:
-- punch wire = remove insulation
-- right click with insulation = add/replace insulation