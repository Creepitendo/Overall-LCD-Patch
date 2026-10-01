from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from enum import Enum
import asyncio

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

buffer = asyncio.Queue()

class DataType(Enum):
    TEXT="text"
    PICTURE="picture"

class TextData(BaseModel):
    text: str
    x: int
    y: int
    textSize: int
    textColor: int
    backgroundColor: int

class PictureData(BaseModel):
    picture: List[int]


@app.post("/text")
async def upload_text(data: TextData):
    queueCount = buffer.qsize()
    await buffer.put((DataType.TEXT, data.model_dump()))

    return {
        "queueCount": queueCount
    }

@app.post("/picture")
async def upload_picture(data: PictureData):
    queueCount = buffer.qsize()
    await buffer.put((DataType.PICTURE, data.model_dump()))

    return {
        "queueCount": queueCount
    }

@app.get("/lcd_request")
async def get_lcd_request():
    dataPresent = True
    if not buffer.empty():
        data = await buffer.get()
    else:
        dataPresent = False

    if dataPresent:
        return {
            "type": data[0].value,
            "dataPresent": dataPresent,
            "queueCount": buffer.qsize(),
            "data": data[1],
        }
    else:
        return {
            "type": "None",
            "dataPresent": dataPresent,
            "queueCount": buffer.qsize(),
            "data": "None",
        }