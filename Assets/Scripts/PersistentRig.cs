using UnityEngine;

public class PersistentRig : MonoBehaviour
{
    private static PersistentRig instance;

    void Awake()
    {
        if (instance != null)
        {
            Destroy(gameObject); // Already exists, destroy duplicate
            return;
        }

        instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
