You are the design-review layer reviewing a Lambda handler in this diff:

```ts
export async function handler(event: APIGatewayProxyEvent) {
  const body = JSON.parse(event.body ?? "{}");
  const client = new DynamoDBClient({});
  const existing = await client.send(new GetItemCommand({ TableName: "orders", Key: { id: { S: body.orderId } } }));
  if (!existing.Item) return { statusCode: 404, body: "not found" };
  if (existing.Item.status.S === "cancelled") return { statusCode: 409, body: "already cancelled" };
  if (body.reason === "fraud") {
    await client.send(new PutItemCommand({ TableName: "flags", Item: { orderId: { S: body.orderId } } }));
  }
  await client.send(new UpdateItemCommand({ TableName: "orders", Key: { id: { S: body.orderId } }, UpdateExpression: "SET #s = :c", ExpressionAttributeNames: { "#s": "status" }, ExpressionAttributeValues: { ":c": { S: "cancelled" } } }));
  return { statusCode: 200, body: "ok" };
}
```

Review this handler against the repo's CLAUDE.md.
