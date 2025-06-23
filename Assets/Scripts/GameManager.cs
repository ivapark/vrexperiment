using UnityEngine;

public class GameManager : MonoBehaviour
{
    public static GameManager Instance;

    public Bounds PenaltyPos { get; set; }
    public Vector3 TarPos { get; set; }
    public Vector3 ReachEndpt { get; set; }
    public float tarSize = 0.05f;
    public int Points { get; set; }

    void Awake()
    {
        if (Instance == null) { Instance = this; DontDestroyOnLoad(gameObject); }
        else Destroy(gameObject);
    }
}