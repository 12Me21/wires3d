-- Wire cutters
minetest.register_craft({
	output = "wires3d:wire_cutters",
	recipe = {
		{"default:steel_ingot",""                   ,"default:steel_ingot"},
		{""                   ,"default:steel_ingot",""                   },
		{"group:stick"        ,""                   ,"group:stick"        },
	},
})

-- Insulation
minetest.register_craft({
	output = minetest.itemstring_with_palette("wires3d:insulation 3", 255),
	recipe = {{"mesecons_materials:fiber"}},
})

-- wire
minetest.register_craft({
	output = "wires3d:wire_0_off",
	recipe = {{"group:mesecon_conductor_craftable"}},
})

-- will probably change
minetest.register_craft({
	output = "wires3d:color_machine",
	type = "shapeless",
	recipe = {"wires3d:insulation","default:furnace"},
})

-- =====
-- Gates
-- =====

minetest.register_craft({
	output = "wires3d:diode_off",
	recipe = {
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
	},
})

minetest.register_craft({
	output = "wires3d:or_gate_off",
	type = "shapeless",
	recipe = {"wires3d:diode_off","wires3d:diode_off"},
})

minetest.register_craft({
	output = "wires3d:and_gate_off",
	recipe = {
		{"","mesecons_materials:silicon",""},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","group:mesecon_conductor_craftable",""},
	},
})

minetest.register_craft({
	output = "wires3d:xor_gate_off",
	recipe = {
		{"mesecons_materials:silicon","","mesecons_materials:silicon"},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"mesecons_materials:silicon","group:mesecon_conductor_craftable","mesecons_materials:silicon"},
	},
})

minetest.register_craft({
	output = "wires3d:not_gate_off",
	recipe = {
		{"","default:mese_crystal",""},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","default:mese_crystal",""},
	},
})

minetest.register_craft({
	output = "wires3d:nor_gate_off",
	type = "shapeless",
	recipe = {"wires3d:or_gate_off","wires3d:not_gate_off"},
})

minetest.register_craft({
	output = "wires3d:nand_gate_off",
	type = "shapeless",
	recipe = {"wires3d:and_gate_off","wires3d:not_gate_off"},
})

minetest.register_craft({
	output = "wires3d:nxor_gate_off",
	type = "shapeless",
	recipe = {"wires3d:xor_gate_off","wires3d:not_gate_off"},
})

minetest.register_craft({
	output = "wires3d:and_not_gate_off",
	recipe = {
		{"mesecons_materials:silicon","mesecons_materials:silicon","mesecons_materials:silicon"},
		{"group:mesecon_conductor_craftable","mesecons_materials:silicon","group:mesecon_conductor_craftable"},
		{"","group:mesecon_conductor_craftable",""},
	},
})

minetest.register_craft({
	output = "wires3d:or_not_gate_off",
	type = "shapeless",
	recipe = {"wires3d:and_not_gate_off","wires3d:not_gate_off"},
})

-- tool idea
-- better screwdriver
-- right click = rotate node around normal of clicked face
-- left click = rotate node around normal of adjacent face nearest to clicked location (sector)
-- a lot more complicated to implement though...