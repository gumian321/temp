public class TurretsDataStore : Singleton<TurretsDataStore>
{
	private static float TurretRecoilRange = 0.15f;

	public static float GetTurretRecoilRange()
	{
		return TurretRecoilRange;
	}

	public static float GetTurretRange(RangeType turretRange)
	{
		return turretRange switch
		{
			RangeType.Short => 5f, 
			RangeType.MidShort => 7f, 
			RangeType.Medium => 9f, 
			RangeType.Long => 12f, 
			RangeType.veryLong => 15f, 
			RangeType.superLong => 20f, 
			_ => 0f, 
		};
	}
}
