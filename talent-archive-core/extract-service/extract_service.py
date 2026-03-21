#!/usr/bin/env python3
"""
English Extraction Service using spaCy NER + SkillNER
Integrates with 4-box framework: Extract -> Normalize -> Tagging -> Match

Output format compatible with rb_extracted_tag / rb_tag_evidence tables.
"""

import io
import json
import sys
from typing import List, Dict, Any, Optional
from flask import Flask, request, jsonify
from flask_cors import CORS

try:
    import pdfplumber
    PDFPLUMBER_AVAILABLE = True
except ImportError:
    pdfplumber = None
    PDFPLUMBER_AVAILABLE = False

try:
    from docx import Document as DocxDocument
    DOCX_AVAILABLE = True
except ImportError:
    DocxDocument = None
    DOCX_AVAILABLE = False

try:
    import spacy
    SPACY_AVAILABLE = True
except ImportError as e:
    print(f"Warning: spaCy not available: {e}. Please install dependencies: pip install -r requirements.txt", file=sys.stderr)
    spacy = None
    SPACY_AVAILABLE = False

# SkillNER is not a standard PyPI package, using fallback skill extraction instead
SKILLNER_AVAILABLE = False
SkillExtractor = None

app = Flask(__name__)
CORS(app)

# Global models (lazy loaded)
nlp = None
skill_extractor = None


def load_models():
    """Load spaCy and SkillNER models (lazy initialization)"""
    global nlp, skill_extractor
    
    if not SPACY_AVAILABLE or spacy is None:
        print("Error: spaCy is not installed. Please install: pip install spacy", file=sys.stderr)
        sys.exit(1)
    
    if nlp is None:
        try:
            # Try loading transformer model first (better accuracy)
            nlp = spacy.load("en_core_web_trf")
            print("Loaded spaCy en_core_web_trf model", file=sys.stderr)
        except OSError:
            # Fallback to smaller model if transformer model not available
            try:
                nlp = spacy.load("en_core_web_sm")
                print("Loaded spaCy en_core_web_sm model (fallback)", file=sys.stderr)
            except OSError as e:
                print(f"Error: spaCy English model not found: {e}", file=sys.stderr)
                print("Please download model: python -m spacy download en_core_web_sm", file=sys.stderr)
                sys.exit(1)
    
    # SkillNER not available, using fallback skill extraction method
    skill_extractor = None
    if not SKILLNER_AVAILABLE:
        print("Using fallback skill extraction (keyword-based).", file=sys.stderr)
    
    return nlp, skill_extractor


def extract_entities_spacy(text: str, nlp_model) -> List[Dict[str, Any]]:
    """
    Extract named entities using spaCy NER.
    Returns: List of {type, text, start, end, label}
    """
    doc = nlp_model(text)
    entities = []
    
    for ent in doc.ents:
        entities.append({
            "type": "ner",
            "label": ent.label_,
            "text": ent.text,
            "normalized": ent.text.lower().strip(),
            "start": ent.start_char,
            "end": ent.end_char,
            "evidence": text[max(0, ent.start_char - 20):min(len(text), ent.end_char + 20)]
        })
    
    return entities


def extract_skills_skillner(text: str, skill_extractor_model) -> List[Dict[str, Any]]:
    """
    Extract skills using SkillNER.
    Returns: List of {type, text, normalized, evidence}
    """
    if skill_extractor_model is None:
        return []
    
    try:
        # SkillNER API: extract_skills(text) returns list of skill strings
        skills = skill_extractor_model.extract_skills(text)
        
        entities = []
        for skill in skills:
            # Find skill in text (case-insensitive)
            skill_lower = skill.lower()
            text_lower = text.lower()
            idx = text_lower.find(skill_lower)
            
            if idx >= 0:
                # Extract context as evidence
                start = max(0, idx - 30)
                end = min(len(text), idx + len(skill) + 30)
                evidence = text[start:end].strip()
                
                entities.append({
                    "type": "skill",
                    "label": "SKILL",
                    "text": skill,
                    "normalized": skill.lower().strip(),
                    "start": idx,
                    "end": idx + len(skill),
                    "evidence": evidence
                })
        
        return entities
    except Exception as e:
        print(f"SkillNER extraction error: {e}", file=sys.stderr)
        return []


def extract_skills_fallback(text: str, nlp_model) -> List[Dict[str, Any]]:
    """
    Fallback skill extraction using spaCy patterns and common tech keywords.
    """
    # Common tech skills patterns (can be expanded)
    tech_keywords = [
        "python", "java", "javascript", "typescript", "react", "vue", "angular",
        "docker", "kubernetes", "aws", "azure", "gcp", "linux", "sql", "nosql",
        "mongodb", "postgresql", "mysql", "redis", "kafka", "rabbitmq",
        "spring", "django", "flask", "node.js", "express", "git", "ci/cd",
        "jenkins", "terraform", "ansible", "puppet", "chef"
    ]
    
    text_lower = text.lower()
    skills = []
    
    for keyword in tech_keywords:
        idx = text_lower.find(keyword)
        if idx >= 0:
            start = max(0, idx - 30)
            end = min(len(text), idx + len(keyword) + 30)
            evidence = text[start:end].strip()
            
            skills.append({
                "type": "skill",
                "label": "SKILL",
                "text": keyword,
                "normalized": keyword.lower().strip(),
                "start": idx,
                "end": idx + len(keyword),
                "evidence": evidence
            })
    
    return skills


def normalize_canonical(entity: Dict[str, Any], entity_type: str) -> str:
    """
    Convert extracted entity to canonical format compatible with rb_baseline_term.
    Format: {type}/{normalized}
    Examples: skill/python, ner/ORG/Google, ner/DATE/2020
    """
    entity_type_map = {
        "skill": "skill",
        "ner": "ner"
    }
    
    prefix = entity_type_map.get(entity.get("type", ""), "other")
    
    if prefix == "skill":
        return f"skill/{entity['normalized']}"
    elif prefix == "ner":
        label = entity.get("label", "UNKNOWN")
        normalized = entity.get("normalized", "")
        return f"ner/{label}/{normalized}"
    else:
        return f"other/{entity.get('normalized', '')}"


def process_text(text: str, doc_type: str, source_file: Optional[str] = None) -> Dict[str, Any]:
    """
    Core pipeline: load models → extract skills → extract NER → normalize → dedupe → summary.
    Returns a dict ready to be passed to jsonify().
    """
    nlp_model, skill_model = load_models()

    entities = []
    if skill_model:
        entities.extend(extract_skills_skillner(text, skill_model))
    else:
        entities.extend(extract_skills_fallback(text, nlp_model))
    entities.extend(extract_entities_spacy(text, nlp_model))

    for entity in entities:
        entity["canonical"] = normalize_canonical(entity, entity.get("type", ""))

    seen: set = set()
    unique_entities = []
    for entity in entities:
        canonical = entity["canonical"]
        if canonical not in seen:
            seen.add(canonical)
            unique_entities.append(entity)

    skill_count = sum(1 for e in unique_entities if e["type"] == "skill")
    ner_count = sum(1 for e in unique_entities if e["type"] == "ner")

    if source_file:
        summary = f"Extracted {skill_count} skills and {ner_count} named entities from {doc_type.lower()} file '{source_file}'"
    else:
        summary = f"Extracted {skill_count} skills and {ner_count} named entities from {doc_type.lower()}"

    result: Dict[str, Any] = {
        "entities": unique_entities,
        "summary": summary,
        "extractor": "spacy+skillner",
        "extractor_version": "1.0",
        "doc_type": doc_type,
    }
    if source_file is not None:
        result["source_file"] = source_file
        result["extracted_text_length"] = len(text)
    return result


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "ok", "models_loaded": nlp is not None})


@app.route('/extract', methods=['POST'])
def extract():
    """
    Extract entities from English resume/JD text.
    
    Request body:
    {
        "text": "resume or JD text...",
        "doc_type": "RESUME" | "JD" (optional)
    }
    
    Response:
    {
        "entities": [
            {
                "type": "skill" | "ner",
                "label": "SKILL" | "PERSON" | "ORG" | "DATE" | ...,
                "text": "original text",
                "normalized": "normalized form",
                "canonical": "skill/python" | "ner/ORG/Google" | ...,
                "start": 0,
                "end": 6,
                "evidence": "context around the entity"
            }
        ],
        "summary": "brief summary",
        "extractor": "spacy+skillner",
        "extractor_version": "1.0"
    }
    """
    try:
        data = request.get_json()
        if not data or "text" not in data:
            return jsonify({"error": "Missing 'text' field"}), 400
        
        text = data["text"]
        doc_type = data.get("doc_type", "RESUME")
        
        if not text or not text.strip():
            return jsonify({"error": "Empty text"}), 400

        return jsonify(process_text(text, doc_type))
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/extract/batch', methods=['POST'])
def extract_batch():
    """
    Batch extraction for multiple texts.
    
    Request body:
    {
        "texts": [
            {"text": "...", "doc_type": "RESUME"},
            {"text": "...", "doc_type": "JD"}
        ]
    }
    """
    try:
        data = request.get_json()
        if not data or "texts" not in data:
            return jsonify({"error": "Missing 'texts' field"}), 400
        
        results = []
        for item in data["texts"]:
            # Reuse single extract logic
            result = extract()
            if result.status_code == 200:
                results.append(result.get_json())
            else:
                results.append({"error": "Extraction failed"})
        
        return jsonify({"results": results})
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """Extract plain text from PDF bytes using pdfplumber."""
    if not PDFPLUMBER_AVAILABLE:
        raise RuntimeError("pdfplumber is not installed. Run: pip install pdfplumber")
    pages = []
    with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                pages.append(text)
    return "\n".join(pages)


def extract_text_from_docx(file_bytes: bytes) -> str:
    """Extract plain text from DOCX bytes using python-docx."""
    if not DOCX_AVAILABLE:
        raise RuntimeError("python-docx is not installed. Run: pip install python-docx")
    doc = DocxDocument(io.BytesIO(file_bytes))
    return "\n".join(para.text for para in doc.paragraphs if para.text.strip())


@app.route('/extract/file', methods=['POST'])
def extract_file():
    """
    Extract entities from an uploaded PDF or DOCX resume file.

    Request: multipart/form-data
      - file: the resume file (.pdf or .docx)
      - doc_type: 'RESUME' | 'JD' (optional, default 'RESUME')

    Response: same schema as POST /extract
    """
    try:
        if 'file' not in request.files:
            return jsonify({"error": "Missing 'file' field in multipart form"}), 400

        uploaded_file = request.files['file']
        filename = uploaded_file.filename or ""
        doc_type = request.form.get('doc_type', 'RESUME')

        file_bytes = uploaded_file.read()
        if not file_bytes:
            return jsonify({"error": "Uploaded file is empty"}), 400

        # Detect file type by extension (case-insensitive)
        lower_name = filename.lower()
        if lower_name.endswith('.pdf'):
            text = extract_text_from_pdf(file_bytes)
        elif lower_name.endswith('.docx'):
            text = extract_text_from_docx(file_bytes)
        else:
            return jsonify({"error": f"Unsupported file type: '{filename}'. Only .pdf and .docx are supported."}), 415

        if not text or not text.strip():
            return jsonify({"error": "Could not extract any text from the uploaded file"}), 422

        return jsonify(process_text(text, doc_type, source_file=filename))

    except RuntimeError as e:
        return jsonify({"error": str(e)}), 501
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    # Load models on startup
    load_models()
    
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    print(f"Starting extraction service on port {port}...", file=sys.stderr)
    app.run(host="0.0.0.0", port=port, debug=False)
