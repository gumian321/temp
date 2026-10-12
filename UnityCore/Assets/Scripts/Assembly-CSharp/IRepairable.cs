public interface IRepairable
{
	float GetDamagePercent();

	void Repair(float repairAmount);

	bool CanRepair();

	bool IsBeingRepaired();

	void SetRepairStatue(bool statue);
}
