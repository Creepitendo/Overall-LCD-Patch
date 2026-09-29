from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import asyncio

app = FastAPI()

buffer = asyncio.Queue()

class TextData(BaseModel):
    type: str
    text: str
    x: int
    y: int
    textSize: int
    textColor: int
    backgroundColor: int

class PictureData(BaseModel):
    type: str
    picture: List[int]


@app.post("/text")
async def receive_data(data: TextData):
    await buffer.put(data.model_dump())

    return {
        "status": "received",
        "position": buffer.qsize()
    }

@app.post("/picture")
async def receive_data(data: PictureData):
    await buffer.put(data.model_dump())
    
    return {
        "status": "received",
        "position": buffer.qsize()
    }

@app.get("/data")
async def get_data():
    items = []

    if not buffer.empty():
        items.append(await buffer.get())

    return {
        "data": items
    }