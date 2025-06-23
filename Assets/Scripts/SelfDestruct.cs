using UnityEngine;

public class SelfDestruct : MonoBehaviour
{
    public float lifetime = 2f;

    void Start()
    {
        Destroy(gameObject, lifetime);
    }
}
