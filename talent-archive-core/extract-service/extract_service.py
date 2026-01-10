#!/usr/bin/env python3
"""
English Extraction Service using spaCy NER + SkillNER
Integrates with 4-box framework: Extract -> Normalize -> Tagging -> Match

Output format compatible with rb_extracted_tag / rb_tag_evidence tables.
"""

import json
import sys
from typing import List, Dict, Any, Optional
from flask import Flask, request, jsonify
from flask_cors import CORS

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
        
        # Load models if not already loaded
        nlp_model, skill_model = load_models()
        
        # Extract entities
        entities = []
        
        # 1. Extract skills using SkillNER (or fallback)
        if skill_model:
            skills = extract_skills_skillner(text, skill_model)
        else:
            skills = extract_skills_fallback(text, nlp_model)
        entities.extend(skills)
        
        # 2. Extract NER entities using spaCy
        ner_entities = extract_entities_spacy(text, nlp_model)
        entities.extend(ner_entities)
        
        # 3. Add canonical format
        for entity in entities:
            entity["canonical"] = normalize_canonical(entity, entity.get("type", ""))
        
        # 4. Deduplicate by canonical (keep first occurrence)
        seen = set()
        unique_entities = []
        for entity in entities:
            canonical = entity["canonical"]
            if canonical not in seen:
                seen.add(canonical)
                unique_entities.append(entity)
        
        # 5. Generate summary
        skill_count = sum(1 for e in unique_entities if e["type"] == "skill")
        ner_count = sum(1 for e in unique_entities if e["type"] == "ner")
        summary = f"Extracted {skill_count} skills and {ner_count} named entities from {doc_type.lower()}"
        
        return jsonify({
            "entities": unique_entities,
            "summary": summary,
            "extractor": "spacy+skillner",
            "extractor_version": "1.0",
            "doc_type": doc_type
        })
    
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


if __name__ == "__main__":
    # Load models on startup
    load_models()
    
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    print(f"Starting extraction service on port {port}...", file=sys.stderr)
    app.run(host="0.0.0.0", port=port, debug=False)
