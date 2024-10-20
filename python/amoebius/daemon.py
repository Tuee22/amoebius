
import asyncio

async def main()->None:
    print("Daemon started")
    try:
        while True:
            # Simulate a long-running task
            print("Daemon is running...")
            await asyncio.sleep(5)  # Sleep for 5 seconds
    except asyncio.CancelledError:
        print("Daemon is shutting down...")

if __name__ == "__main__":
    asyncio.run(main())