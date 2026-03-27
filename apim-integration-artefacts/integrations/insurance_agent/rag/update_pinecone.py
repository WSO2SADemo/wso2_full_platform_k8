import os
import pinecone
from mistralai import Mistral
from dotenv import load_dotenv
from pypdf import PdfReader

# 1. Load keys from environment variables
load_dotenv()
MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")

# 2. PDF path
PDF_PATH = "/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/apim-integration-artefacts/integrations/insurance_agent/rag/Principal-Sample-Life-Insurance-Policy.pdf"

# 3. Read PDF
def read_pdf(path):
    reader = PdfReader(path)
    full_text = ""
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        if text:
            full_text += f"\n--- Page {i+1} ---\n{text}"
    print(f"Extracted text from {len(reader.pages)} pages")
    return full_text

# 4. Initialize clients
mistral_client = Mistral(api_key=MISTRAL_API_KEY)
pc = pinecone.Pinecone(api_key=PINECONE_API_KEY)

# 5. Auto-create Pinecone index if it doesn't exist
if "insurance-policy" not in pc.list_indexes().names():
    print("Creating index...")
    pc.create_index(
        name="insurance-policy",
        dimension=1024,
        metric="cosine",
        spec=pinecone.ServerlessSpec(
            cloud="aws",
            region="us-east-1"
        )
    )
    print("Index created!")
else:
    print("Index already exists, skipping creation...")

index = pc.Index("insurance-policy")

# 6. Chunk the text
def chunk_text(text, chunk_size=500, overlap=50):
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = " ".join(words[i:i + chunk_size])
        chunks.append(chunk)
    return chunks

# 7. Generate embeddings using Mistral
def get_embedding(text):
    response = mistral_client.embeddings.create(
        inputs=text,
        model="mistral-embed"
    )
    return response.data[0].embedding

# 8. Main - read, chunk, embed, upsert
def ingest_pdf(pdf_path):
    print(f"Reading PDF: {pdf_path}")
    policy_text = read_pdf(pdf_path)

    print("Chunking text...")
    chunks = chunk_text(policy_text)
    print(f"Created {len(chunks)} chunks")

    print("Generating embeddings and upserting to Pinecone...")
    vectors = []
    for i, chunk in enumerate(chunks):
        print(f"  Processing chunk {i+1}/{len(chunks)}...")
        embedding = get_embedding(chunk)
        vectors.append({
            "id": f"policy-s655-chunk-{i}",
            "values": embedding,
            "metadata": {
                "text": chunk,
                "policy_no": "GL S655",
                "policyholder": "Rhode Island John Doe",
                "insurer": "Principal Life Insurance Company",
                "source": pdf_path,
                "page": i
            }
        })

    index.upsert(vectors=vectors)
    print(f"Successfully upserted {len(vectors)} chunks to Pinecone!")

# 9. Query function
def query_policy(question):
    print(f"\nQuerying: {question}")
    query_embedding = get_embedding(question)
    results = index.query(
        vector=query_embedding,
        top_k=3,
        include_metadata=True
    )
    for match in results.matches:
        print(f"Score: {match.score:.3f}")
        print(f"Text: {match.metadata['text']}\n")

# 10. Run
if __name__ == "__main__":
    ingest_pdf(PDF_PATH)

    # Example queries
    query_policy("What is the death benefit for a member?")
    query_policy("How long is the grace period for premium payment?")