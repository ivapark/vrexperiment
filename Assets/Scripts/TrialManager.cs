using System.Collections.Generic;
using UnityEngine;

public class TrialManager : MonoBehaviour
{
    public static TrialManager Instance;

    public int currentTrial = 0;
    public int repetitionsPerCondition = 4; // Each condition repeated 4 times
    private List<TrialCondition> allTrials;

    private const int targetCount = 9;
    private const int penaltyCount = 7; // up, down, left, right, front, back, none

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

    void GenerateTrials()
    {
        allTrials = new List<TrialCondition>();

        // Create all combinations of target and penalty
        for (int t = 0; t < targetCount; t++)
        {
            for (int p = 0; p < penaltyCount; p++)
            {
                for (int r = 0; r < repetitionsPerCondition; r++)
                {
                    allTrials.Add(new TrialCondition(t, p));
                }
            }
        }

        ShuffleList(allTrials);
    }

    /// <summary>
    /// Get the next trial condition. Returns null if all trials are done.
    /// </summary>
    public TrialCondition GetNextTrial()
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
    public void ReinsertTrial(TrialCondition failedTrial)
    {
        // Random index between current position and the end of the list
        int randomIndex = Random.Range(currentTrial, allTrials.Count + 1);

        if (randomIndex >= allTrials.Count)
            allTrials.Add(failedTrial);
        else
            allTrials.Insert(randomIndex, failedTrial);
    }

    void ShuffleList<T>(List<T> list)
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
public class TrialCondition
{
    public int targetIndex;
    public int penaltyIndex;

    public TrialCondition(int t, int p)
    {
        targetIndex = t;
        penaltyIndex = p;
    }
}
