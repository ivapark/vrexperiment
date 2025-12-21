using System.Collections.Generic;
using UnityEngine;

public class TargetOnlyTrialManager : MonoBehaviour
{
    public static TargetOnlyTrialManager Instance;

    public int currentTrial = 0;
    public int repetitionsPerCondition = 25; // Repeat each target condition 25 times
    private List<TargetOnlyCondition> allTrials;

    private const int targetCount = 9;

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
        allTrials = new List<TargetOnlyCondition>();

        for (int t = 0; t < targetCount; t++)
        {
            for (int r = 0; r < repetitionsPerCondition; r++)
            {
                allTrials.Add(new TargetOnlyCondition(t));
            }
        }

        ShuffleList(allTrials);
    }

    public TargetOnlyCondition GetNextTrial()
    {
        if (currentTrial < allTrials.Count)
        {
            return allTrials[currentTrial++];
        }
        else
        {
            return null;
        }
    }

    public int TotalTrialCount => allTrials?.Count ?? 0;

    public void ReinsertTrial(TargetOnlyCondition failedTrial)
    {
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
public class TargetOnlyCondition
{
    public int targetIndex;

    public TargetOnlyCondition(int t)
    {
        targetIndex = t;
    }
}
