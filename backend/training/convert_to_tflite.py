"""
File: convert_to_tflite.py

This script loads a Keras model from a specified path and converts it to TensorFlow Lite format.
"""

#!/usr/bin/env python3
# convert_to_tflite.py

import tensorflow as tf
import os

# Paths
model_keras_path = "model_save/model.keras"   # Input Keras model
tflite_output_path = "model_save/model.tflite"  # Output TFLite model

# Ensure output directory exists
os.makedirs(os.path.dirname(tflite_output_path), exist_ok=True)

try:
    # Load Keras model
    print(f"[INFO] Loading Keras model from: {model_keras_path}")
    model = tf.keras.models.load_model(model_keras_path)

    # Initialize TFLite converter
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optional: optimize for size and latency (mobile-friendly)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # Convert to TFLite
    tflite_model = converter.convert()

    # Save TFLite model
    with open(tflite_output_path, 'wb') as f:
        f.write(tflite_model)

    print(f"[SUCCESS] TFLite model created at: {tflite_output_path}")

except Exception as e:
    print(f"[ERROR] Failed to convert model to TFLite: {e}")
