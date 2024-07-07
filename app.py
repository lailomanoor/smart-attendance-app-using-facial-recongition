from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import cv2
import numpy as np
import pandas as pd
from deepface import DeepFace
from mtcnn import MTCNN
from sklearn.preprocessing import LabelEncoder
from sklearn.svm import SVC
import joblib
import tempfile

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Define paths
MODEL_PATH = "C:/Users/arzoo/Desktop/attendance-proj/model.pkl"
ENCODER_PATH = "C:/Users/arzoo/Desktop/attendance-proj/label_encoder.pkl"
STUDENTS_FILE = "C:/Users/arzoo/Desktop/attendance-proj/students_names.xlsx"
OUTPUT_PATH = "attendance.xlsx"

# Load model and label encoder
clf = joblib.load(MODEL_PATH)
label_encoder = joblib.load(ENCODER_PATH)

def enhance_face(input_image):
    try:
        denoised_img = cv2.fastNlMeansDenoisingColored(input_image, None, 6, 6, 7, 21)
        upscaled_img = cv2.resize(denoised_img, None, fx=6, fy=6, interpolation=cv2.INTER_LINEAR)
        return upscaled_img
    except Exception as e:
        print(f"Error enhancing image: {e}")
        return None

def detect_faces_with_mtcnn(image):
    detector = MTCNN()
    results = detector.detect_faces(image)
    faces = []
    for result in results:
        x, y, w, h = result["box"]
        face = image[y:y+h, x:x+w]
        faces.append(face)
    return faces

def evaluate_on_test_image(test_image):
    enhanced_image = enhance_face(test_image)
    if enhanced_image is None:
        return set()

    faces = detect_faces_with_mtcnn(enhanced_image)
    if not faces:
        return set()

    recognized_names = set()
    for face in faces:
        try:
            embedding = DeepFace.represent(face, model_name="VGG-Face", enforce_detection=False)
            
            # Debugging print statements
            #print(f"Embedding type: {type(embedding)}")
            #print(f"Embedding content: {embedding}")

            # Ensure embedding is a list of numerical values
            if isinstance(embedding, list) and isinstance(embedding[0], dict):
                embedding = [item['embedding'] for item in embedding]
            
            if isinstance(embedding, list):
                embedding = np.array(embedding)
            
            # Ensure the embedding is 2D
            if embedding.ndim == 1:
                embedding = embedding.reshape(1, -1)
            
            if embedding.size == 0:
                print("Empty embedding, skipping this face")
                continue
            
            prediction = clf.predict_proba(embedding)[0]
            predicted_label_idx = np.argmax(prediction)
            confidence = prediction[predicted_label_idx]
            predicted_label = label_encoder.inverse_transform([predicted_label_idx])[0]
            recognized_names.add(predicted_label)
        except Exception as e:
            print(f"Error in face recognition: {e}")
    
    return recognized_names

def write_attendance_to_excel(recognized_names):
    try:
        df = pd.read_excel(STUDENTS_FILE)
        df["Attendance"] = df["Name"].apply(lambda x: "P" if x in recognized_names else "A")
        df.to_excel(OUTPUT_PATH, index=False)
    except Exception as e:
        print(f"Error writing to Excel: {e}")

@app.route('/upload', methods=['POST'])
def process_image():
    if 'image' not in request.files:
        return jsonify({"error": "No image provided"}), 400

    image_file = request.files['image']
    temp_path = tempfile.NamedTemporaryFile(delete=False)
    image_path = temp_path.name
    image_file.save(image_path)

    try:
        test_image = cv2.imread(image_path)
        if test_image is None:
            return jsonify({"error": "Invalid image file"}), 400
        
        recognized_names = evaluate_on_test_image(test_image)
        write_attendance_to_excel(recognized_names)
    finally:
        #os.unlink(image_path)  # Clean up the temporary file
        print("Testing.......")

    return jsonify({"message": "Attendance processed successfully"}), 200

if __name__ == '__main__':
    app.run(debug=True, port=4000)  # Specify the port here
