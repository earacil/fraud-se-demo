from deepface import DeepFace

embedding = DeepFace.represent(
    img_path="data/images/face-2.png",
    model_name="ArcFace"
)

print(embedding[0]["embedding"])