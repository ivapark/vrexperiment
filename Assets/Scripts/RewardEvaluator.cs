using UnityEngine;

public class RewardEvaluator : MonoBehaviour
{
    public GameObject feedbackGainPrefab;
    public GameObject feedbackLossPrefab;
    public GameObject feedbackNeutralPrefab;

    public float targetRadius = 0.02f;
    public float feedbackOffsetZ = 0.1f;
    public float feedbackLifetime = 0.7f;

    public string Evaluate(Vector3 reachEnd, Vector3 targetPos, Bounds penaltyBounds)
    {
        GameObject prefabToSpawn;
        string outcome;

        bool hitTarget = Vector3.Distance(reachEnd, targetPos) <= targetRadius;
        bool hitPenalty = penaltyBounds.Contains(reachEnd);

        if (hitTarget && hitPenalty)
        {
            GameManager.Instance.Points -= 200; // Mixed outcome: less penalty than full miss
            prefabToSpawn = feedbackLossPrefab;
            outcome = "Hit Both";
        }
        else if (hitPenalty)
        {
            GameManager.Instance.Points -= 500;
            prefabToSpawn = feedbackLossPrefab;
            outcome = "Hit Penalty";
        }
        else if (hitTarget)
        {
            GameManager.Instance.Points += 300;
            prefabToSpawn = feedbackGainPrefab;
            outcome = "Hit Target";
        }
        else
        {
            GameManager.Instance.Points += 0;
            prefabToSpawn = feedbackNeutralPrefab;
            outcome = "Missed";
        }

        Vector3 feedbackPos = reachEnd + new Vector3(0, 0, feedbackOffsetZ);
        //GameObject feedback = Instantiate(prefabToSpawn, feedbackPos, Quaternion.identity);
        //Destroy(feedback, feedbackLifetime);

        return outcome;
    }

}
