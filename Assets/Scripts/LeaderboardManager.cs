using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

[Serializable]
public class LeaderboardEntry
{
    public string playerName;
    public int blockNumber;  // 10, 20, 30, etc.
    public int score;        // cumulative score at that block
}

[Serializable]
public class LeaderboardData
{
    public List<LeaderboardEntry> entries = new List<LeaderboardEntry>();
}

public class LeaderboardManager : MonoBehaviour
{
    public static LeaderboardManager Instance { get; private set; }

    // this MUST be inside the class
    public string experimentType = "LR"; // change in Inspector

    private string filePath;
    public List<LeaderboardEntry> entries = new List<LeaderboardEntry>();

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);

        filePath = Path.Combine(
            Application.persistentDataPath,
            $"leaderboard_{experimentType}.json"
        );

        LoadLeaderboard();
    }

    private void SaveLeaderboard()
    {
        var data = new LeaderboardData { entries = entries };
        string json = JsonUtility.ToJson(data, true);
        File.WriteAllText(filePath, json);
    }

    private void LoadLeaderboard()
    {
        if (!File.Exists(filePath))
        {
            entries = new List<LeaderboardEntry>();
            return;
        }

        string json = File.ReadAllText(filePath);
        var data = JsonUtility.FromJson<LeaderboardData>(json);
        entries = data?.entries ?? new List<LeaderboardEntry>();
    }

    public void AddEntryForBlock(string playerName, int blockNumber, int score)
    {
        entries.RemoveAll(e => e.playerName == playerName && e.blockNumber == blockNumber);

        entries.Add(new LeaderboardEntry
        {
            playerName = playerName,
            blockNumber = blockNumber,
            score = score
        });

        SaveLeaderboard();
    }

    public List<LeaderboardEntry> GetLeaderboardForBlock(int blockNumber)
    {
        return entries
            .Where(e => e.blockNumber == blockNumber)
            .OrderByDescending(e => e.score)
            .ToList();
    }

    public List<LeaderboardEntry> GetFinalLeaderboard()
    {
        return entries
            .GroupBy(e => e.playerName)
            .Select(g => g.OrderByDescending(e => e.blockNumber).First())
            .OrderByDescending(e => e.score)
            .ToList();
    }

    public void ClearAll()
    {
        entries.Clear();
        SaveLeaderboard();
    }
}
