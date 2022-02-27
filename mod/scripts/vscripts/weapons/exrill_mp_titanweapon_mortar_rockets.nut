global function exrill_OnWeaponPrimaryAttack_titanweapon_mortar_rockets
global function exrill_OnWeaponActivate_titanweapon_mortar_rockets
global function exrill_OnWeaponDeactivate_titanweapon_mortar_rockets
global function exrill_TitanAbilityMortarInit
#if SERVER
global function exrill_OnWeaponNPCPrimaryAttack_titanweapon_mortar_rockets
#endif

const SALVOROCKETS_MISSILE_SFX_LOOP			= "Weapon_Sidwinder_Projectile"
const SALVOROCKETS_NUM_ROCKETS_PER_SHOT 	= 1
const SALVOROCKETS_APPLY_RANDOM_SPREAD 		= true
const SALVOROCKETS_LAUNCH_OUT_ANG 			= 50
const SALVOROCKETS_LAUNCH_OUT_TIME 			= 0.20
const SALVOROCKETS_LAUNCH_IN_LERP_TIME 		= 0.2
const SALVOROCKETS_LAUNCH_IN_ANG 			= -10
const SALVOROCKETS_LAUNCH_IN_TIME 			= 0.10
const SALVOROCKETS_LAUNCH_STRAIGHT_LERP_TIME = 0.1
const SALVOROCKETS_DEBUG_DRAW_PATH 			= false
void function exrill_TitanAbilityMortarInit(){
    RegisterSignal( "MortarCamToggle" )
}
var function exrill_OnWeaponPrimaryAttack_titanweapon_mortar_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	bool shouldPredict = weapon.ShouldPredictProjectiles()

	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	float speed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
	entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, 1, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, true, 0 )
	if ( player.IsPlayer() )
		PlayerUsedOffhand( player, weapon )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}
void function exrill_OnWeaponActivate_titanweapon_mortar_rockets(entity weapon){
	#if CLIENT
	Minimap_SetZoomScale( 5.0 )
	Minimap_SetSizeScale( 2 )
	thread showicon(weapon)
	#endif
}
void function exrill_OnWeaponDeactivate_titanweapon_mortar_rockets(entity weapon){
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.Signal("MortarCamToggle")
}
void function showicon(entity weapon){
	//todo: learn basic maths
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.EndSignal("MortarCamToggle")
	weaponOwner.EndSignal("OnDeath")
	weaponOwner.EndSignal("OnDestroy")
	OnThreadEnd(
        function() : ( weaponOwner )
            {
                #if CLIENT
				Minimap_SetZoomScale( 2.5 )
				Minimap_SetSizeScale( 1 )
				#endif
            }
        )
	while(true){
		if(IsValid(weapon)){
		vector origin = weaponOwner.EyePosition()
		vector direction = AnglesToForward(weaponOwner.EyeAngles())
		float speed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
		#if CLIENT
		vector lastdirection = direction
		vector lastvelocity = (speed*direction)/10
		vector laststep = (<origin.x, origin.y, origin.z>) + lastvelocity/100
		TraceResults traceResult = TraceLine( laststep, laststep + lastvelocity)
		while(traceResult.endPos == laststep+lastvelocity){
			lastvelocity.z = lastvelocity.z - ((750*weapon.GetWeaponSettingFloat( eWeaponVar.projectile_gravity_scale ))/100)
			laststep = traceResult.endPos
			traceResult = TraceLine( laststep, laststep + lastvelocity , null, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		}
		Minimap_Ping( traceResult.endPos, 50, 0.2, <255,255,255> , true )
		#endif
		}
		wait 0.2
	}
}

#if SERVER
var function exrill_OnWeaponNPCPrimaryAttack_titanweapon_mortar_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_salvo_rockets( weapon, attackParams )
}
#endif