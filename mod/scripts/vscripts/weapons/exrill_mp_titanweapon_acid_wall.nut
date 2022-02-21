global function MpTitanweaponAcidWall_Init

global function OnWeaponPrimaryAttack_AcidWall
global function OnProjectileCollision_AcidWall
global function OnWeaponActivate_titancore_Acid_wall

#if SERVER
global function OnWeaponNpcPrimaryAttack_AcidWall
global function CreateAcidWallSegment
#endif

const asset ACID_WALL_FX = $"P_wpn_meteor_wall"
const asset ACID_WALL_FX_S2S = $"P_wpn_meteor_wall_s2s"
const asset ACID_WALL_CHARGED_ADD_FX = $"impact_exp_burst_FRAG_2"

const string ACID_WALL_PROJECTILE_SFX = "flamewall_ACID_start"
const string ACID_WALL_GROUND_SFX = "Explo_ThermiteGrenade_Impact_3P"
const string ACID_WALL_GROUND_BEGINNING_SFX = "flamewall_ACID_burn_front"
const string ACID_WALL_GROUND_MIDDLE_SFX = "flamewall_ACID_burn_middle"
const string ACID_WALL_GROUND_END_SFX = "flamewall_ACID_burn_end"

global const float ACID_WALL_THERMITE_DURATION = 8.2
global const float PAS_VENOM_ACIDWALL_DURATION = 8.2
global const float SP_ACID_WALL_DURATION_SCALE = 1.75

void function MpTitanweaponAcidWall_Init()
{
	PrecacheParticleSystem( ACID_WALL_FX )
	PrecacheParticleSystem( ACID_WALL_CHARGED_ADD_FX )

	if ( GetMapName() == "sp_s2s" )
	{
		PrecacheParticleSystem( ACID_WALL_FX_S2S )
	}

	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_flame_wall, AcidWall_DamagedTarget )
	#endif
}

void function OnWeaponActivate_titancore_Acid_wall(entity weapon){}
var function OnWeaponPrimaryAttack_AcidWall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	//ThrowDeployable( weapon, attackParams, 0.63, OnSlowTrapPlanted, <90,0,0> )
	entity player = weapon.GetWeaponOwner()

	vector attackPos
	if ( IsValid( player ) )
		attackPos = GetDeployableThrowStartPos( player, attackParams.pos )
	vector angles = VectorToAngles( attackParams.dir )
	attackPos.z = attackPos.z +25
	vector angularVelocity = <0,0,0>
	float fuseTime = 0.0
	float speed = weapon.GetWeaponSettingFloat(eWeaponVar.projectile_launch_speed)/2200
	vector forward = AnglesToForward( angles )
	if ( forward.x < 80 )
		speed = GraphCapped( forward.x, 0, 80, speed, speed * 3 )

	vector velocity = forward * speed

	entity deployable = weapon.FireWeaponGrenade( attackPos, attackParams.dir, angularVelocity, fuseTime, damageTypes.explosive, damageTypes.explosive, false, true, true )
	//entity deployable = Grenade_Launch( weapon, attackParams.pos, (attackParams.dir * 1), projectilePredicted, projectileLagCompensated )
	print(weapon.GetWeaponChargeLevel())
	#if SERVER
		if ( deployable )
		{
			deployable.proj.savedAngles = Vector( 0, angles.y, 0 )
			Grenade_Init( deployable, weapon )
			thread OnProjectilePlanted( deployable, OnPoisonWallPlanted )
		}
	#endif
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

#if SERVER
void function OnProjectilePlanted( entity projectile, void functionref(entity) deployFunc )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.WaitSignal( "Planted" )

	deployFunc( projectile )
}
#endif
vector function GetDeployableThrowStartPos( entity player, vector baseStartPos )
{
	if ( player.IsTitan() )
	{
		int attachID = player.LookupAttachment( "TITAN_GRENADE" )
		vector attackPos = player.GetAttachmentOrigin( attachID )
		vector attackDir = player.GetAttachmentForward( attachID )
		return attackPos + ( attackDir * 50 )
	}

	vector attackPos = player.OffsetPositionFromView( baseStartPos, Vector( 15.0, 0.0, 0.0 ) )	// forward, right, up
	return attackPos
}
void function OnPoisonWallPlanted( entity projectile )
{
	#if SERVER
		//thread DeployPoisonWall( projectile )
		
		vector origin = OriginToGround( projectile.GetOrigin() )
		vector angles = projectile.proj.savedAngles
		angles = < angles.x , angles.y, angles.z >
		projectile.SetOrigin(< origin.x, origin.y, origin.z+100 >)
		origin = projectile.GetOrigin()
		float duration = ACID_WALL_THERMITE_DURATION
		if ( GAMETYPE == GAMEMODE_SP )
			duration *= SP_ACID_WALL_DURATION_SCALE
		entity inflictor = CreateOncePerTickDamageInflictorHelper( duration )
		inflictor.SetOrigin( origin )
		entity _parent = projectile.GetParent()
		if ( IsValid( _parent ) )
			projectile.SetParent( _parent, "", true, 0 )
		entity myParent = _parent
		// Increase the radius a bit so AI proactively try to get away before they have a chance at taking damage
		entity owner = projectile.GetOwner()
		entity movingGeo = ( myParent && myParent.HasPusherRootParent() ) ? myParent : null
		if ( movingGeo )
		{
			inflictor.SetParent( movingGeo, "", true, 0 )}
	
			vector direction = AnglesToForward( <angles.x,angles.y+90,angles.z> )
			print("direction "+direction)
			print("initial angles "+angles)
			const float FUSE_TIME = 0.0
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			thread SpawnPoisonWave( projectile, 0, inflictor, origin-100*direction, direction )
			direction = AnglesToForward( <angles.x,angles.y-90,angles.z> )
			thread SpawnPoisonWave( projectile, 0, inflictor, origin-100*direction, direction )


	#endif
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_AcidWall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_AcidWall( weapon, attackParams )
}
#endif

void function OnProjectileCollision_AcidWall( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
}

#if SERVER

void function SpawnPoisonWave( entity projectile, int projectileCount, entity inflictor, vector origin, vector direction )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetAbsAngles( projectile.GetAngles() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, origin, direction, CreateAcidWallSegment )
	projectile.Destroy()
}

bool function CreateAcidWallSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	entity owner = projectile.GetOwner()

	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		array<string> mods = projectile.ProjectileGetMods()
		float duration
		int damageSource
		if ( mods.contains( "pas_scorch_flamecore" ) )
		{
			damageSource = eDamageSourceId.mp_titancore_ACID_wave_secondary
			duration = 1.5
		}
		else
		{
			damageSource = eDamageSourceId.mp_titanweapon_flame_wall
			duration = mods.contains( "pas_scorch_firewall" ) ? PAS_SCORCH_FIREWALL_DURATION : ACID_WALL_THERMITE_DURATION
		}

		if ( IsSingleplayer() )
		{
			if ( owner.IsPlayer() || Flag( "SP_MeteorIncreasedDuration" ) )
			{
				duration *= SP_ACID_WALL_DURATION_SCALE
			}
		}

		entity thermiteParticle
		//regular script path
		if ( !movingGeo )
		{
			thermiteParticle = CreateThermiteTrail( pos, angles, owner, inflictor, duration, ACID_WALL_FX, damageSource )
			EffectSetControlPointVector( thermiteParticle, 1, projectile.proj.savedOrigin )
			AI_CreateDangerousArea_Static( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true, pos )
		}
		else
		{
			if ( GetMapName() == "sp_s2s" )
			{
				angles = <0,90,0>//wind dir
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, ACID_WALL_FX_S2S, damageSource )
			}
			else
			{
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, ACID_WALL_FX, damageSource )
			}

			if ( movingGeo == projectile.proj.savedMovingGeo )
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, projectile.proj.savedRelativeDelta, projectile.proj.savedMovingGeo )
			}
			else
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, GetRelativeDelta( pos, movingGeo ), movingGeo )
			}
			AI_CreateDangerousArea( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true )
		}

		//EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_SFX )
		int maxSegments = expect int( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_max_count" ) )
		//figure out why it's starting at 1 but ending at 14.
		if ( waveCount == 1 )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_BEGINNING_SFX )
		else if ( waveCount == ( maxSegments - 1 ) )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_END_SFX )
		else if ( waveCount == maxSegments / 2  )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_MIDDLE_SFX )
	}

	projectile.proj.savedOrigin = pos
	if ( IsValid( movingGeo ) )
	{
		projectile.proj.savedRelativeDelta = GetRelativeDelta( pos, movingGeo )
		projectile.proj.savedMovingGeo = movingGeo
	}

	return true
}

void function EffectUpdateControlPointVectorOnMovingGeo( entity thermiteParticle, int cpIndex, vector relativeDelta, entity movingGeo )
{
	thermiteParticle.EndSignal( "OnDestroy" )

	while ( 1 )
	{
		vector origin = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )

		EffectSetControlPointVector( thermiteParticle, cpIndex, origin )
		WaitFrame()
	}
}

void function AcidWall_DamagedTarget( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	Thermite_DamagePlayerOrNPCSounds( ent )
	Scorch_SelfDamageReduction( ent, damageInfo )

	StatusEffect_AddTimed( ent, eStatusEffect.move_slow, 0.7, 1, 1 )
	DamageInfo_ScaleDamage( damageInfo, 0.2 )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || attacker.GetTeam() == ent.GetTeam() )
		return

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 )
	{
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
	}
}

#endif