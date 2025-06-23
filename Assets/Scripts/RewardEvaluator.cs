using UnityEngine;

public class RewardEvaluator : MonoBehaviour
{
    public GameObject feedbackGainPrefab;
    public GameObject feedbackLossPrefab;
    public GameObject feedbackNeutralPrefab;

    public float targetRadius = 0.05f;
    public float feedbackOffsetZ = 0.1f; // offset in front of reach point
    public float feedbackLifetime = 0.7f; // in seconds

    public void Evaluate(Vector3 reachEnd, Vector3 targetPos, Bounds penaltyBounds)
    {
        GameObject prefabToSpawn;

        if (penaltyBounds.Contains(reachEnd))
        {
            GameManager.Instance.Points -= 500;
            prefabToSpawn = feedbackLossPrefab;
        }
        else if (Vector3.Distance(reachEnd, targetPos) <= targetRadius)
        {
            GameManager.Instance.Points += 300;
            prefabToSpawn = feedbackGainPrefab;
        }
        else
        {
            GameManager.Instance.Points += 0;
            prefabToSpawn = feedbackNeutralPrefab;
        }

        // offset forward (relative to world space Z-axis)
        Vector3 feedbackPos = reachEnd + new Vector3(0, 0, feedbackOffsetZ);

        GameObject feedback = Instantiate(prefabToSpawn, feedbackPos, Quaternion.identity);
        Destroy(feedback, feedbackLifetime);
    }
}
