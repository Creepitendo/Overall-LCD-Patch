#pragma once

#include <atomic>

enum class DisplayMode {
  IDLE,
  TEXT,
  PICTURE
};

class PixelBuffer {
  private:
    size_t row_size;
    size_t column_size;
    size_t row_counter = 0;

    uint16_t* pixels;
    size_t capacity;
    size_t head = 0;
    size_t tail = 0;
    std::atomic<size_t> count{0};
  
  public:
    PixelBuffer(size_t row_size, size_t column_size, size_t pixel_capacity) {
      this->row_size = row_size;
      this->column_size = column_size;
      this->capacity = pixel_capacity;
      this->pixels = new uint16_t[this->capacity];
    }

    ~PixelBuffer() {
      delete[] this->pixels;
    }

    void reset() {
      this->head = 0;
      this->tail = 0;
      this->count = 0;
      this->row_counter = 0;
    }

    void addPixel(uint16_t pixel) {
      if (this->count < this->capacity) {
        this->pixels[head] = pixel;
        this->head = (this->head + 1) % this->capacity;
        this->count++;
      }
      else {
        Serial.println("ERROR: Pixel could not be safed => Too much pixels for Buffer capacity");
      }  
    }

    bool getRow(uint16_t* destination) {
      if (this->count < this->row_size) {
        return false;
      }
      
      for (size_t i = 0; i < this->row_size; i++) {
        destination[i] = this->pixels[tail];
        this->tail = (this->tail + 1) % this->capacity;
      }
      this->count -= this->row_size;
      return true;
    }

    void nextRow() {
      this->row_counter = (this->row_counter + 1) % this->column_size;
    }

    int getCurrentRowCount() {
      return this->row_counter;
    }
};

void endianSwap(uint16_t* ptr, size_t width, size_t height) {
  for (size_t i = 0; i < width*height; i++) {
    uint16_t color = ptr[i];
    ptr[i] = (color >> 8) | (color << 8); // High-Byte <-> Low-Byte
  }
}