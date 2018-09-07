-- Wire cutters
minetest.register_craft({
	output = "3d_wires:wire_cutters",
	recipe = {
		{"default:steel_ingot",""                   ,"default:steel_ingot"},
		{""                   ,"default:steel_ingot",""                   },
		{"group:stick"        ,""                   ,"group:stick"        },
	},
})

-- Insulation
minetest.register_craft({
	output = minetest.itemstring_with_palette("3d_wires:insulation 3", 255),
	recipe = {{"mesecons_materials:fiber"}},
})

-- wire
minetest.register_craft({
	output = "3d_wires:wire_0_off",
	recipe = {{"group:mesecon_conductor_craftable"}},
})

-- will probably change
minetest.register_craft({
	output = "3d_wires:color_machine",
	type = "shapeless",
	recipe = {"3d_wires:insulation","default:furnace"},
})

-- =====
-- Gates
-- =====

minetest.register_craft({
	output = "3d_wires:diode_off",
	recipe = {
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
	},
})

minetest.register_craft({
	output = "3d_wires:or_gate_off",
	type = "shapeless",
	recipe = {"3d_wires:diode_off","3d_wires:diode_off"},
})

minetest.register_craft({
	output = "3d_wires:and_gate_off",
	recipe = {
		{"","mesecons_materials:silicon",""},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","group:mesecon_conductor_craftable",""},
	},
})

minetest.register_craft({
	output = "3d_wires:xor_gate_off",
	recipe = {
		{"mesecons_materials:silicon","","mesecons_materials:silicon"},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"mesecons_materials:silicon","group:mesecon_conductor_craftable","mesecons_materials:silicon"},
	},
})

minetest.register_craft({
	output = "3d_wires:not_gate_off",
	recipe = {
		{"","default:mese_crystal",""},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","default:mese_crystal",""},
	},
})

minetest.register_craft({
	output = "3d_wires:nor_gate_off",
	type = "shapeless",
	recipe = {"3d_wires:or_gate_off","3d_wires:not_gate_off"},
})

minetest.register_craft({
	output = "3d_wires:nand_gate_off",
	type = "shapeless",
	recipe = {"3d_wires:and_gate_off","3d_wires:not_gate_off"},
})

minetest.register_craft({
	output = "3d_wires:nxor_gate_off",
	type = "shapeless",
	recipe = {"3d_wires:xor_gate_off","3d_wires:not_gate_off"},
})

minetest.register_craft({
	output = "3d_wires:and_not_gate_off",
	recipe = {
		{"mesecons_materials:silicon","mesecons_materials:silicon","mesecons_materials:silicon"},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","group:mesecon_conductor_craftable",""},
	},
})

minetest.register_craft({
	output = "3d_wires:or_not_gate_off",
	type = "shapeless",
	recipe = {"3d_wires:and_not_gate_off","3d_wires:not_gate_off"},
})

-- tool idea
-- better screwdriver
-- right click = rotate node around normal of clicked face
-- left click = rotate node around normal of adjacent face nearest to clicked location (sector)
-- a lot more complicated to implement though...