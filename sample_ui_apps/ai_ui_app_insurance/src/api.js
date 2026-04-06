export async function callAI(url, apiKey, payload) {
  const start = performance.now();
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'ApiKey': apiKey,
      },
      body: JSON.stringify(payload),
    });
    const elapsed = Math.round(performance.now() - start);
    let data;
    try { data = await res.json(); } catch { data = null; }
    return { status: res.status, elapsed, data, ok: res.ok };
  } catch (err) {
    const elapsed = Math.round(performance.now() - start);
    return { status: 0, elapsed, data: { error: err.message }, ok: false };
  }
}
