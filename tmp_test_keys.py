def key(url, w, h):
    return f"{url}_{w}_{h}"

pairs = [
    ("vx_assets/uuid/1178700211048_1.png", 800, -1),
    ("vx_assets/uuid/1178700211048.png", 1, -1),
    ("vx_assets/uuid/1178700211048_1", 800, -1),
    ("vx_assets/uuid/1178700211048", 1, 800),
    ("vx_assets/uuid/561345151048.png", 800, -1),
]
keys = [key(u,w,h) for u,w,h in pairs]
for i, k in enumerate(keys):
    print(pairs[i], '->', k)
print('dupes:', [k for k in keys if keys.count(k) > 1])
