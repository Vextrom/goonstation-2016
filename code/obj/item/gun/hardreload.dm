/obj/item/gun/hardreload
	name = "hardreload weapon"
	icon = 'icons/obj/gun.dmi'
	item_state = "gun"
	m_amt = 2000
	var/obj/item/ammo/bullets/ammo = null
	var/max_ammo_capacity = 1 // How much ammo can this gun hold? Don't make this null (Convair880).
	var/caliber = null // Can be a list too. The .357 Mag revolver can also chamber .38 Spc rounds, for instance (Convair880).
	var/closed = 1

	var/auto_eject = 0 // Do we eject casings on firing, or on reload?
	var/casings_to_eject = 0 // If we don't automatically ejected them, we need to keep track (Convair880).

	add_residue = 1 // Does this gun add gunshot residue when fired? Kinetic guns should (Convair880).

	// caliber list: update as needed
	// 0.308 - rifles
	// 0.357 - revolver
	// 0.38 - detective
	// 0.41 - derringer
	// 0.72 - shotgun shell, 12ga
	// 1.57 - 40mm shell
	// 1.58 - RPG-7 (Tube is 40mm too, though warheads are usually larger in diameter.)

	examine()
		set src in usr
		if (src.ammo && (src.ammo.amount_left > 0))
			src.desc = "There are [src.ammo.amount_left] bullets of [src.ammo.sname] left!"
		else
			src.desc = "There are 0 bullets left!"
		if (current_projectile)
			src.desc += "<br>Each shot will currently use [src.current_projectile.cost] bullets!"
		else
			src.desc += "<br><span style=\"color:red\">*ERROR* No output selected!</span>"
		..()

	update_icon()
		return 0

	canshoot()
		if(src.ammo && src.current_projectile)
			if(src.ammo:amount_left >= src.current_projectile:cost)
				if(closed)
					return 1
		return 0

	process_ammo(var/mob/user)
		if(src.ammo && src.current_projectile)
			if(src.ammo.use(current_projectile.cost))
				return 1
		boutput(user, "<span style=\"color:red\">*click* *click*</span>")
		return 0

	attackby(obj/item/ammo/bullets/b as obj, mob/user as mob)
		if(istype(b, /obj/item/ammo/bullets))
			if(!closed)
				switch (src.ammo.loadammo(b,src))
					if(0)
						user.show_text("You can't reload this gun.", "red")
						return
					if(1)
						user.show_text("This ammo won't fit!", "red")
						return
					if(2)
						user.show_text("There's no ammo left in [b.name].", "red")
						return
					if(3)
						user.show_text("[src] is full!", "red")
						return
					if(4)
						user.visible_message("<span style=\"color:red\">[user] reloads [src].</span>", "<span style=\"color:red\">There wasn't enough ammo left in [b.name] to fully reload [src]. It only has [src.ammo.amount_left] rounds remaining.</span>")
						src.logme_temp(user, src, b) // Might be useful (Convair880).
						return
					if(5)
						user.visible_message("<span style=\"color:red\">[user] reloads [src].</span>", "<span style=\"color:red\">You fully reload [src] with ammo from [b.name]. There are [b.amount_left] rounds left in [b.name].</span>")
						src.logme_temp(user, src, b)
						return
					if(6)
						switch (src.ammo.swap(b,src))
							if(0)
								user.show_text("This ammo won't fit!", "red")
								return
							if(1)
								user.visible_message("<span style=\"color:red\">[user] reloads [src].</span>", "<span style=\"color:red\">You swap out the magazine. Or whatever this specific gun uses.</span>")
							if(2)
								user.visible_message("<span style=\"color:red\">[user] reloads [src].</span>", "<span style=\"color:red\">You swap [src]'s ammo with [b.name]. There are [b.amount_left] rounds left in [b.name].</span>")
						src.logme_temp(user, src, b)
						return
			else
				user.show_text("The gun has to be open!", "red")
				return	
		else
			..()

	attack_self(mob/user as mob)
		return

	attack_hand(mob/user as mob)
	// Added this to make manual reloads possible (Convair880).
		if(closed)
			return ..()
		else
			if ((src.loc == user) && user.find_in_hand(src)) // Make sure it's not on the belt or in a backpack.
				src.add_fingerprint(user)
				if (src.sanitycheck(0, 1) == 0)
					user.show_text("You can't unload this gun.", "red")
					return
				if (src.ammo.amount_left <= 0)
					return

				// Make a copy here to avoid item teleportation issues.
				var/obj/item/ammo/bullets/ammoHand = new src.ammo.type
				ammoHand.amount_left = src.ammo.amount_left
				ammoHand.name = src.ammo.name
				ammoHand.icon = src.ammo.icon
				ammoHand.icon_state = src.ammo.icon_state
				ammoHand.ammo_type = src.ammo.ammo_type
				ammoHand.delete_on_reload = 1 // No duplicating empty magazines, please (Convair880).
				ammoHand.update_icon()
				user.put_in_hand_or_drop(ammoHand)

				// The gun may have been fired; eject casings if so.
				src.ejectcasings()
				src.casings_to_eject = 0

				src.update_icon()
				src.ammo.amount_left = 0
				src.add_fingerprint(user)
				ammoHand.add_fingerprint(user)

				user.visible_message("<span style=\"color:red\">[user] unloads [src].</span>", "<span style=\"color:red\">You unload [src].</span>")
				//DEBUG_MESSAGE("Unloaded [src]'s ammo manually.")
				return

		return ..()

	attack(mob/M as mob, mob/user as mob)
	// Finished Cogwerks' former WIP system (Convair880).
		if (src.canshoot() && user.a_intent != "help")
			if (src.auto_eject)
				var/turf/T = get_turf(src)
				if(T)
					if (src.current_projectile.casing && (src.sanitycheck(1, 0) == 1))
						var/number_of_casings = max(1, src.current_projectile.shot_number)
						//DEBUG_MESSAGE("Ejected [number_of_casings] casings from [src].")
						for (var/i = 1, i <= number_of_casings, i++)
							var/obj/item/casing/C = new src.current_projectile.casing(T)
							C.forensic_ID = src.forensic_ID
							C.loc = T
			else
				if (src.casings_to_eject < 0)
					src.casings_to_eject = 0
				src.casings_to_eject += src.current_projectile.shot_number
		..()

	shoot(var/target,var/start ,var/mob/user)
		if (src.canshoot())
			if (src.auto_eject)
				var/turf/T = get_turf(src)
				if(T)
					if (src.current_projectile.casing && (src.sanitycheck(1, 0) == 1))
						var/number_of_casings = max(1, src.current_projectile.shot_number)
						//DEBUG_MESSAGE("Ejected [number_of_casings] casings from [src].")
						for (var/i = 1, i <= number_of_casings, i++)
							var/obj/item/casing/C = new src.current_projectile.casing(T)
							C.forensic_ID = src.forensic_ID
							C.loc = T
			else
				if (src.casings_to_eject < 0)
					src.casings_to_eject = 0
				src.casings_to_eject += src.current_projectile.shot_number
		..()

	proc/ejectcasings()
		if ((src.casings_to_eject > 0) && src.current_projectile.casing && (src.sanitycheck(1, 0) == 1))
			var/turf/T = get_turf(src)
			if(T)
				//DEBUG_MESSAGE("Ejected [src.casings_to_eject] [src.current_projectile.casing] from [src].")
				var/obj/item/casing/C = null
				while (src.casings_to_eject > 0)
					C = new src.current_projectile.casing(T)
					C.forensic_ID = src.forensic_ID
					C.loc = T
					src.casings_to_eject--
		return

	// Don't set this too high. Absurdly large reloads and item spawning can cause a lot of lag. (Convair880).
	proc/sanitycheck(var/casings = 0, var/ammo = 1)
		if (casings && (src.casings_to_eject > 30 || src.current_projectile.shot_number > 30))
			logTheThing("debug", usr, null, "<b>Convair880</b>: [usr]'s gun ([src]) ran into the casings_to_eject cap, aborting.")
			if (src.casings_to_eject > 0)
				src.casings_to_eject = 0
			return 0
		if (ammo && (src.max_ammo_capacity > 200 || src.ammo.amount_left > 200))
			logTheThing("debug", usr, null, "<b>Convair880</b>: [usr]'s gun ([src]) ran into the magazine cap, aborting.")
			return 0
		return 1

/obj/item/gun/hardreload/dbarrelgun
	name = "Double Barrel Shotgun"
	desc = "This thing could kill a demon!"
	icon_state = "dbarrel"
	force = 12.0
	contraband = 10
	caliber = 0.80
	max_ammo_capacity = 1
	auto_eject = 0
	w_class = 2.0

	New()
		ammo = new/obj/item/ammo/bullets/dbarrelclip
		current_projectile = new/datum/projectile/bullet/doublebarrel
		..()

	attack_self(mob/user as mob)
		if(closed)
			closed = 0
			icon_state = "dbarrel_broke"
			playsound(get_turf(src), "sound/weapons/dbl_open.ogg", 100, 1)
			user.visible_message("<span style=\"color:red\">[user] opens their [src] with a snap. Damn that's rad. </span>","<span style=\"color:red\">You break the gun open.</span>")
			if (src.ammo.amount_left <= 0)
				// The gun may have been fired; eject casings if so.
				if ((src.casings_to_eject > 0) && src.current_projectile.casing)
					if (src.sanitycheck(1, 0) == 0)
						logTheThing("debug", usr, null, "<b>Convair880</b>: [usr]'s gun ([src]) ran into the casings_to_eject cap, aborting.")
						src.casings_to_eject = 0
						return
					else
						src.casings_to_eject = 2
						user.show_text("You eject [src.casings_to_eject] casings from [src].", "red")
						src.ejectcasings()
						return
				else
					user.show_text("[src] is empty!", "red")
					return
		else
			closed = 1
			icon_state = "dbarrel"
			playsound(get_turf(src), "sound/weapons/dbl_close.ogg", 100, 1)
			user.visible_message("<span style=\"color:red\">[user] snaps their [src] closed. Oh fuck!</span>","<span style=\"color:red\">You snap the gun closed.</snap>")
		return