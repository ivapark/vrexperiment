using UnityEngine;

public class TrialManager : MonoBehaviour
{
    public static TrialManager Instance;
    public int currentTrial = 0;
    public int totalTrials = 10;

    void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else
        {
            Destroy(gameObject);
        }
    }
}
