# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import json

import functions_framework
import requests
import vertexai

from google.cloud import bigquery
from vertexai.generative_models import Content, GenerativeModel, FunctionDeclaration, Part, Tool


PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION = os.getenv("GCP_REGION")

vertexai.init(project=PROJECT_ID, location=REGION)

MODEL_NAME="gemini-1.5-flash"


# TODO Challenge 3: Edit the following SQL to return the top result for a question. Make sure to use ? as the 
# placeholder for the `question` parameter, see https://cloud.google.com/bigquery/docs/parameterized-queries#python
SQL = """
"""

def get_relevant_video(question: str) -> str:
    """Given a question return the GCS URI for the video that matches the best using semantic search with embeddings

    DO NOT EDIT.

    Args:
        question: a natural language question, e.g. what's the forecast for Amsterdam for next week.

    Returns:
        the GCS URI for the most relevant video, e.g gs://foo/bar.mp4, empty string if nothing is found
    """
    if not question or not SQL.strip():
        return ""
    
    client = bigquery.Client(project=PROJECT_ID)
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter(None, "STRING", question),
        ]
    )
    job = client.query(SQL, job_config=job_config)
    row = next(job.result(), None)

    return row.get("uri") if row else ""


def get_weather_with_rag(question: str, relevant_video_uri: str) -> str:
    """Returns weather information using the provided video uri as the context for RAG.

    Args:
        question: a natural language question about the weather, e.g. what was the max temparature in London on Monday
    
    Returns:
        a string indicating the weather information, or `NO DATA` if the question cannot be answered
    """
    # TODO Challenge 4: Provide the video as context for RAG and configure system instructions
    model = GenerativeModel(MODEL_NAME)
    parts = []
    if parts:
        response = model.generate_content(parts)
        return response.text
    else:
        return ""


def _city_name_to_lat_long(city: str) -> tuple[float, float]:
    """Given a city name, this method returns the latitude and longitude information as a tuple

    This method uses an LLM to resolve the coordinates, but typically a geolocation API or database would be a more
    efficient way.

    DO NOT EDIT.

    Args:
        city: name of the city to resolve (with or without country), e.g. Istanbul, Turkey
    
    Returns:
        the latitude and longitude information in a tuple (in that order)
    
    Raises:
        ValueError if the city is not a valid city
    """
    model = GenerativeModel(MODEL_NAME)
    prompt = f"What is the latitude and longitude of {city}? Output in JSON. Do not format."
    response = model.generate_content(prompt)
    parsed = json.loads(response.text)
    if "error" in parsed:
        raise ValueError(parsed["error"])
    else:
        return (parsed["latitude"], parsed["longitude"])


def _historical_weather(lat:float, lng: float, date: str) -> dict:
    """Uses an external service (Open-Meteo) to return weather information (min and max temp in Celsius for now).

    DO NOT EDIT.
    
    Args:
        lat: a float representing the latitude for the weather information
        lng: a float the longitude for the weather information
        date: a string representing the date for which the weather information should be looked up, in YYYY-MM-DD format
    
    Returns:
        min and max temperature in JSON format
    """
    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": lat,
        "longitude": lng,
        "start_date": date,
        "end_date": date,
        "daily": "weather_code,temperature_2m_max,temperature_2m_min"
    }
    response = requests.get(url, params=params)
    return response.json()


def _contains_api_call_params(response: str) -> bool:
    """Returns a boolean indicating whether the model has been able to parse the correct parameters

    Args:
        response: result of model.generate_content

    Returns:
        a boolean indicating whether the `city` and `date` information is included in the response
    """
    return len(response.candidates) > 0 and len(response.candidates[0].function_calls) > 0 and \
        "city" in response.candidates[0].function_calls[0].args and \
        "date" in response.candidates[0].function_calls[0].args


def get_weather_with_api(question: str) -> str:
    """Returns weather information using an external API. This method parses the natural language question and extracts
    the parameters to be used when calling the external service.

    Args:
        question: a natural language question about the weather, e.g. what was the max temparature in London on Monday

    Returns:
        a string indicating the weather information
    """
    model = GenerativeModel(MODEL_NAME)

    # TODO Challenge 5: Complete the implementation of the FunctionDeclaration for weather tool
    function_name = "get_weather_info"
    function_decl = FunctionDeclaration(
        name=function_name,
        description="",  # add a description
        parameters={
            "type": "object",
            "properties": {  # add city & date
            }
        }
    )
    # Step 1: extract city & date information from the question and call the external service with that information
    weather_tool = Tool(function_declarations=[function_decl])
    response = model.generate_content(question, tools=[weather_tool])
    if not _contains_api_call_params(response):
        return "NO DATA"
    function_call = response.candidates[0].function_calls[0]
    city = function_call.args["city"]
    date = function_call.args["date"]
    lat, lng = _city_name_to_lat_long(city)
    api_response = _historical_weather(lat, lng, date)

    # Step 2: given the original question and the results from the API, answer the question
    response = model.generate_content([
        Content(role="user", parts=[Part.from_text(question)]),  # original question
        response.candidates[0].content,  # original response
        Content(parts=[Part.from_function_response(name=function_name, response={"content": api_response})]) # API resp
    ])

    return response.text


@functions_framework.http
def on_post(request):
    """Triggered when an http request is made

    DO NOT EDIT until Challenge 5.

    Args:
        request: the http request
    
    Returns:
        Answers related to weather related questions
    """
    request_json = request.get_json(silent=True)

    question = request_json["question"] if request_json and "question" in request_json else ""

    relevant_video_uri = get_relevant_video(question)
    print("Relevant Video URI:", relevant_video_uri)

    weather_info = get_weather_with_rag(question, relevant_video_uri)
    print("Weather info with RAG:", weather_info)

    # TODO Challenge 5: Uncommment the following 3 lines
    # if "NO DATA" in weather_info:
    #     weather_info = get_weather_with_api(question)
    #     print("Weather info with API:", weather_info)
    
    return weather_info
        
