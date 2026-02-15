"""
HTTP client module for fetching training data from the Spring Boot API.
"""

import requests
import json
import sys
from typing import List, Dict, Any, Optional


class APIError(Exception):
    """Custom exception for API errors."""
    pass


def fetch_training_data(
    api_url: str = "http://localhost:18080",
    job_id: Optional[int] = None,
    format: str = "json"
) -> List[Dict[str, Any]]:
    """
    Fetch training data from the API endpoint.
    
    Args:
        api_url: Base URL of the API (default: http://localhost:18080)
        job_id: Optional job ID to filter data (supports both jobId and job_id query params)
        format: Response format, either 'json' or 'csv' (default: 'json')
        
    Returns:
        List of dictionaries containing training examples
        
    Raises:
        APIError: If API request fails or returns non-200 status
        ValueError: If response format is invalid
    """
    endpoint = f"{api_url}/api/ml/training-examples"
    
    # Build query parameters (support both jobId and job_id)
    params = {"format": format}
    if job_id is not None:
        params["jobId"] = job_id
        params["job_id"] = job_id  # Support both formats
    
    try:
        response = requests.get(endpoint, params=params, timeout=30)
    except requests.exceptions.ConnectionError as e:
        raise APIError(
            f"Failed to connect to API at {endpoint}\n"
            f"Please ensure the Spring Boot application is running.\n"
            f"Error: {str(e)}"
        ) from e
    except requests.exceptions.Timeout as e:
        raise APIError(f"Request to {endpoint} timed out: {str(e)}") from e
    except requests.exceptions.RequestException as e:
        raise APIError(f"Request failed: {str(e)}") from e
    
    if response.status_code != 200:
        raise APIError(
            f"API returned non-200 status code: {response.status_code}\n"
            f"Response: {response.text[:200]}"
        )
    
    if format.lower() == "json":
        try:
            data = response.json()
            if not isinstance(data, list):
                raise ValueError(f"Expected JSON array, got {type(data)}")
            return data
        except json.JSONDecodeError as e:
            raise APIError(
                f"Invalid JSON response from API:\n{response.text[:500]}\n"
                f"JSON Error: {str(e)}"
            ) from e
    elif format.lower() == "csv":
        # CSV format is handled separately if needed
        raise ValueError("CSV format is not supported in this function. Use JSON format.")
    else:
        raise ValueError(f"Unsupported format: {format}. Use 'json' or 'csv'.")


def validate_data(data: List[Dict[str, Any]]) -> None:
    """
    Validate that the fetched data is not empty and contains required fields.
    
    Args:
        data: List of training examples
        
    Raises:
        ValueError: If data is empty or invalid
    """
    if not data:
        raise ValueError("API returned empty data. No training examples available.")
    
    if not isinstance(data, list):
        raise ValueError(f"Expected list of dictionaries, got {type(data)}")
    
    # Check that each item is a dictionary
    for i, item in enumerate(data):
        if not isinstance(item, dict):
            raise ValueError(f"Item {i} is not a dictionary: {type(item)}")
