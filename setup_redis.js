

async function setupRedis() {
  const headers = {
    'x-api-key': 'A4d9n8b6laenwepqv7ify5fr8i3bv37pozr51esim0bn5lc9sdw',
    'x-api-secret-key': 'S5p7zu4ibne5d9zwp45ncrcrnd13a9cmilrvawzcrcpjg6vk6ti',
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };

  console.log("Creating subscription...");
  const subRes = await fetch('https://api.redislabs.com/v1/fixed/subscriptions', {
    method: 'POST',
    headers,
    body: JSON.stringify({ name: "CasinoR", planId: 20927 })
  });
  const subData = await subRes.json();
  console.log("Subscription Response:", subData);
  
  // Actually wait, sometimes the subscription requires some time or returns an ID.
  const subId = subData.id || subData.resourceId; // Check API response structure
  
  if(!subId) {
    console.error("Failed to get subscription ID");
    return;
  }
  
  console.log("Creating Database under sub", subId);
  const dbRes = await fetch(`https://api.redislabs.com/v1/fixed/subscriptions/${subId}/databases`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      name: "casinodb",
      memoryLimitInGb: 0.03, // 30MB
      supportModules: false,
      clientSslCertificate: ""
    })
  });
  
  const dbData = await dbRes.json();
  console.log("Database Response:", dbData);
}

setupRedis().catch(console.error);
