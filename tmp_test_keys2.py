def key(url, w, h):
    return f"{url}_{w}_{h}"

urls = [
    "vx_assets/uuid/561345151048.png",
    "vx_assets/uuid/1178700211048_1.png",
    "vx_assets/uuid/1178700211048.png",
    "vx_assets/uuid/1178700211048_1",
    "vx_assets/uuid/1178700211048",
]
dims = [(800,-1), (1,-1), (1,800), (800,600), (23,-1)]
keys = {}
for u in urls:
    for w,h in dims:
        k = key(u,w,h)
        if k in keys:
            print('COLLISION:', k)
            print(' ', keys[k], 'vs', (u,w,h))
        keys[k] = (u,w,h)

# specific check
k1 = key("vx_assets/uuid/1178700211048_1.png", 800, -1)
k2 = key("vx_assets/uuid/1178700211048", 1, -1)
k3 = key("vx_assets/uuid/1178700211048_1", 800, -1)
print('k1', k1)
print('k2', k2)
print('k3', k3)
print('k1==k2', k1==k2)
print('k1==k3', k1==k3)
