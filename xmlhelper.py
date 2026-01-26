import asyncio
import websockets
import xmltodict
import json

async def xml_to_json(ws):
    async for message in ws:
        try:
            xml_dict = xmltodict.parse(message)
            json_data = json.dumps(xml_dict)
            await ws.send(json_data)
        except Exception as e:
            await ws.send(json.dumps({"error": str(e)}))

async def main():
    async with websockets.serve(xml_to_json, "localhost", 8765):
        print("WebSocket server running on ws://localhost:8765")
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())


