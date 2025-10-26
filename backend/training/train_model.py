"""
File: train_model.py

This script trains a simple neural network model to classify URLs as phishing or safe 
based on several features extracted from the URLs.
"""

#!/usr/bin/env python3
# train_model.py

import pandas as pd
import numpy as np
import tensorflow as tf
from urllib.parse import urlparse
import ipaddress
from sklearn.model_selection import train_test_split
import os
from sklearn.metrics import precision_score, recall_score, f1_score

"""
featureExtraction method

Extracts several numerical features from the given URL.
"""
def featureExtraction(url):
    """
    Features:
    1) domain_length
    2) having ip address
    3) having @ symbol
    4) url length
    5) url depth
    6) redirection
    7) https in scheme
    8) tinyurl (tinyurl/bit.ly in domain)
    9) prefix_suffix ( '-' in domain)
    """
    try:
        parsed = urlparse(url)
        scheme = parsed.scheme
        domain = parsed.netloc
        path = parsed.path

        # 1. domain_length
        domain_length = len(domain)

        # 2. having ip address
        try:
            ipaddress.ip_address(domain)
            have_ip = 1
        except:
            have_ip = 0

        # 3. having @ symbol
        have_at = 1 if "@" in url else 0

        # 4. url length
        url_length = len(url)

        # 5. url depth
        url_depth = len([x for x in path.split("/") if x != ""])

        # 6. redirection (check if '//' in path)
        redirection = 1 if '//' in path else 0

        # 7. https in scheme
        https_domain = 1 if scheme == "https" else 0

        # 8. tinyurl or bit.ly
        tiny_url = 1 if ('tinyurl' in domain or 'bit.ly' in domain) else 0

        # 9. prefix or suffix in domain
        prefix_suffix = 1 if '-' in domain else 0

        return [
            domain_length,
            have_ip,
            have_at,
            url_length,
            url_depth,
            redirection,
            https_domain,
            tiny_url,
            prefix_suffix
        ]
    except:
        print(f"[ERROR] Failed to parse {url}")
        return [0]*9


"""
train_and_save_model method

Trains a classification model using a dataset of URLs and saves the trained model.
"""
def train_and_save_model(csv_path='data/combined_dataset.csv', model_path='model_save/model.keras'):
    # 1) Read dataset
    df = pd.read_csv(csv_path, on_bad_lines='skip')

    # 2) Build feature matrix (X) and labels (y)
    X = []
    y = df['label'].values

    for url in df['url']:
        feats = featureExtraction(url)
        X.append(feats)

    X = np.array(X, dtype=np.float32)

    # 3) Split data into training and testing sets (80/20)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # 4) Define model
    model = tf.keras.models.Sequential([
        tf.keras.layers.Input(shape=(9,)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(8, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])

    # Learning rate schedule
    initial_learning_rate = 0.001
    lr_schedule = tf.keras.optimizers.schedules.ExponentialDecay(
        initial_learning_rate, decay_steps=1000, decay_rate=0.9
    )
    optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)

    model.compile(
        optimizer=optimizer,
        loss='binary_crossentropy',
        metrics=['accuracy']
    )

    # 5) Train model
    history = model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=64,
        validation_data=(X_test, y_test),
        verbose=1
    )

    # 6) Evaluate model
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    y_pred = (model.predict(X_test) > 0.5).astype(int)

    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)

    print(f"Accuracy: {accuracy * 100:.2f}%")
    print(f"Precision: {precision * 100:.2f}%")
    print(f"Recall: {recall * 100:.2f}%")
    print(f"F1 Score: {f1 * 100:.2f}%")

    # 7) Save model
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    model.save(model_path)
    print(f"[INFO] Model saved to {model_path}")

    return history


if __name__ == "__main__":
    history = train_and_save_model(
        csv_path='data/combined_dataset.csv',
        model_path='model_save/model.keras'
    )

    if history is None:
        print("[ERROR] Training failed")
    else:
        print("[SUCCESS] Model training completed")
