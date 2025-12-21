using System.Collections.Generic;
using UnityEngine;

public class TrialManager27 : MonoBehaviour
{
    public static TrialManager27 Instance;

    public int currentTrial = 0;
    public int repetitionsPerCondition = 4; // Each condition repeated 4 times
    private List<TrialCondition27> allTrials;

    private const int targetCount = 9;  // 3x3 grid (0-8)
    private const int penaltyCount = 3; // left, right, no penalty

    void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
            GenerateTrials();
        }
        else
        {
            Destroy(gameObject);
        }
    }

    /// <summary>
    /// Generates all 27 conditions (target x penalty), each repeated n times.
    /// </summary>
    void GenerateTrials()
    {
        allTrials = new List<TrialCondition27>();
        int conditionIndex = 0;

        for (int t = 0; t < targetCount; t++)
        {
            for (int p = 0; p < penaltyCount; p++)
            {
                for (int r = 0; r < repetitionsPerCondition; r++)
                {
                    allTrials.Add(new TrialCondition27(t, p, conditionIndex));
                }
                conditionIndex++;
            }
        }

        ShuffleList(allTrials);
        Debug.Log($"[TrialManager27] Generated {allTrials.Count} trials with {repetitionsPerCondition} repetitions.");
    }

    /// <summary>
    /// Get the next trial condition. Returns null if all trials are done.
    /// </summary>
    public TrialCondition27 GetNextTrial()
    {
        if (currentTrial < allTrials.Count)
        {
            return allTrials[currentTrial++];
        }
        else
        {
            return null; // No more trials
        }
    }

    public int TotalTrialCount => allTrials != null ? allTrials.Count : 0;

    /// <summary>
    /// Reinserts a failed trial into the list at a random future position.
    /// </summary>
    public void ReinsertTrial(TrialCondition27 failedTrial)
    {
        int randomIndex = Random.Range(currentTrial, allTrials.Count + 1);
        if (randomIndex >= allTrials.Count)
            allTrials.Add(failedTrial);
        else
            allTrials.Insert(randomIndex, failedTrial);
    }

    private void ShuffleList<T>(List<T> list)
    {
        for (int i = 0; i < list.Count; i++)
        {
            T temp = list[i];
            int randomIndex = Random.Range(i, list.Count);
            list[i] = list[randomIndex];
            list[randomIndex] = temp;
        }
    }
}

[System.Serializable]
public class TrialCondition27
{
    public int targetIndex;
    public int penaltyIndex;
    public int conditionIndex; // unique condition number (0-26)

    public TrialCondition27(int t, int p, int c)
    {
        targetIndex = t;
        penaltyIndex = p;
        conditionIndex = c;
    }
}
