from __future__ import annotations

from datetime import date
from typing import Any


HEALTH_PROFILE_FIELDS = {
    "has_diabetes",
    "has_hypertension",
    "has_high_cholesterol",
    "diabetes_type",
    "latest_hba1c",
}


def split_profile_and_health_updates(
    payload_data: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    profile_data: dict[str, Any] = {}
    health_updates: dict[str, Any] = {}

    for key, value in payload_data.items():
        if key in HEALTH_PROFILE_FIELDS:
            health_updates[key] = value
        else:
            profile_data[key] = value

    return profile_data, health_updates


def _condition_name(condition: dict[str, Any]) -> str:
    return str(condition.get("condition_name") or "").strip().lower()


def _restricted_nutrient(condition: dict[str, Any]) -> str:
    nutrient = condition.get("restricted_nutrient") or condition.get(
        "restricted_nutrients"
    )
    return str(nutrient or "").strip().lower()


def is_diabetes_condition(condition: dict[str, Any]) -> bool:
    return "diabetes" in _condition_name(condition)


def is_hypertension_condition(condition: dict[str, Any]) -> bool:
    return "hypertension" in _condition_name(condition)


def is_high_cholesterol_condition(condition: dict[str, Any]) -> bool:
    name = _condition_name(condition)
    nutrient = _restricted_nutrient(condition)
    return (
        "cholesterol" in name
        or "heart disease" in name
        or nutrient == "cholesterol"
    )


def _normalize_health_condition_row(row: dict[str, Any]) -> dict[str, Any] | None:
    condition = row.get("condition") or row.get("health_conditions")
    if not isinstance(condition, dict):
        return None

    normalized = dict(condition)
    metadata = row.get("condition_metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}

    normalized["condition_metadata"] = metadata

    if is_diabetes_condition(normalized):
        if "diabetes_type" in metadata:
            normalized["diabetes_type"] = metadata["diabetes_type"]
        if "latest_hba1c" in metadata:
            normalized["latest_hba1c"] = metadata["latest_hba1c"]

    return normalized


def get_available_health_conditions(supabase: Any) -> list[dict[str, Any]]:
    result = (
        supabase.table("health_conditions")
        .select("*")
        .order("condition_name")
        .execute()
    )
    return result.data or []


def _load_user_health_condition_rows(
    supabase: Any,
    user_id: str,
) -> tuple[list[dict[str, Any]], bool]:
    try:
        result = (
            supabase.table("user_health_conditions")
            .select("health_condition_id, condition_metadata")
            .eq("user_id", user_id)
            .execute()
        )
        return [dict(row) for row in (result.data or [])], True
    except Exception as exc:
        if "condition_metadata" not in str(exc):
            raise

    fallback_result = (
        supabase.table("user_health_conditions")
        .select("health_condition_id")
        .eq("user_id", user_id)
        .execute()
    )

    rows: list[dict[str, Any]] = []
    for row in fallback_result.data or []:
        normalized_row = dict(row)
        normalized_row["condition_metadata"] = {}
        rows.append(normalized_row)

    return rows, False


def get_user_health_conditions(supabase: Any, user_id: str) -> list[dict[str, Any]]:
    rows, _supports_metadata = _load_user_health_condition_rows(supabase, user_id)

    condition_ids = [
        str(row["health_condition_id"])
        for row in rows
        if row.get("health_condition_id")
    ]

    if not condition_ids:
        return []

    condition_result = (
        supabase.table("health_conditions")
        .select("*")
        .in_("id", condition_ids)
        .execute()
    )
    condition_map = {
        str(condition["id"]): dict(condition)
        for condition in condition_result.data or []
        if condition.get("id")
    }

    normalized_conditions: list[dict[str, Any]] = []
    for row in rows:
        condition_id = str(row.get("health_condition_id") or "")
        condition = condition_map.get(condition_id)
        if not condition:
            continue

        normalized = _normalize_health_condition_row(
            {
                "condition": condition,
                "condition_metadata": row.get("condition_metadata") or {},
            }
        )
        if normalized is not None:
            normalized_conditions.append(normalized)

    return normalized_conditions


def derive_health_profile(health_conditions: list[dict[str, Any]]) -> dict[str, Any]:
    diabetes_condition = next(
        (condition for condition in health_conditions if is_diabetes_condition(condition)),
        None,
    )

    return {
        "has_diabetes": diabetes_condition is not None,
        "has_hypertension": any(
            is_hypertension_condition(condition) for condition in health_conditions
        ),
        "has_high_cholesterol": any(
            is_high_cholesterol_condition(condition)
            for condition in health_conditions
        ),
        "diabetes_type": diabetes_condition.get("diabetes_type")
        if diabetes_condition
        else None,
        "latest_hba1c": diabetes_condition.get("latest_hba1c")
        if diabetes_condition
        else None,
        "health_condition_ids": [
            str(condition["id"])
            for condition in health_conditions
            if condition.get("id")
        ],
    }


def _calculate_age_from_birthdate(birthdate_value: Any) -> int | None:
    if birthdate_value in (None, ""):
        return None

    try:
        birthdate = date.fromisoformat(str(birthdate_value))
    except ValueError:
        return None

    today = date.today()
    return today.year - birthdate.year - (
        (today.month, today.day) < (birthdate.month, birthdate.day)
    )


def get_user_profile_with_health(
    supabase: Any,
    user_id: str,
    *,
    include_health_conditions: bool = True,
) -> dict[str, Any] | None:
    profile_result = (
        supabase.table("profiles")
        .select("*")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )

    if not profile_result.data:
        return None

    profile = dict(profile_result.data)
    calculated_age = _calculate_age_from_birthdate(profile.get("birthdate"))
    if calculated_age is not None:
        profile["age"] = calculated_age

    health_conditions = get_user_health_conditions(supabase, user_id)
    profile.update(derive_health_profile(health_conditions))

    if include_health_conditions:
        profile["health_conditions"] = health_conditions

    return profile


def _matching_condition_ids(
    available_conditions: list[dict[str, Any]],
    matcher,
) -> set[str]:
    return {
        str(condition["id"])
        for condition in available_conditions
        if condition.get("id") and matcher(condition)
    }


def _primary_condition_id(
    available_conditions: list[dict[str, Any]],
    matcher,
) -> str | None:
    for condition in available_conditions:
        if condition.get("id") and matcher(condition):
            return str(condition["id"])
    return None


def save_user_health_conditions(
    supabase: Any,
    user_id: str,
    *,
    health_updates: dict[str, Any],
    health_condition_ids: list[str] | list[Any] | None,
) -> list[dict[str, Any]]:
    available_conditions = get_available_health_conditions(supabase)
    existing_conditions = get_user_health_conditions(supabase, user_id)
    _, supports_metadata = _load_user_health_condition_rows(supabase, user_id)

    if health_condition_ids is not None:
        selected_ids = {str(condition_id) for condition_id in health_condition_ids}
    else:
        selected_ids = {
            str(condition["id"])
            for condition in existing_conditions
            if condition.get("id")
        }

        for field_name, matcher in (
            ("has_diabetes", is_diabetes_condition),
            ("has_hypertension", is_hypertension_condition),
            ("has_high_cholesterol", is_high_cholesterol_condition),
        ):
            if field_name not in health_updates:
                continue

            matching_ids = _matching_condition_ids(available_conditions, matcher)
            if health_updates[field_name]:
                if not (selected_ids & matching_ids):
                    primary_id = _primary_condition_id(available_conditions, matcher)
                    if primary_id is not None:
                        selected_ids.add(primary_id)
            else:
                selected_ids -= matching_ids

    existing_metadata_by_id = {
        str(condition["id"]): dict(condition.get("condition_metadata") or {})
        for condition in existing_conditions
        if condition.get("id")
    }

    rows_to_insert: list[dict[str, Any]] = []
    for condition in available_conditions:
        condition_id = str(condition.get("id") or "")
        if not condition_id or condition_id not in selected_ids:
            continue

        metadata = dict(existing_metadata_by_id.get(condition_id, {}))
        if is_diabetes_condition(condition):
            if "diabetes_type" in health_updates:
                if health_updates["diabetes_type"] is None:
                    metadata.pop("diabetes_type", None)
                else:
                    metadata["diabetes_type"] = health_updates["diabetes_type"]

            if "latest_hba1c" in health_updates:
                if health_updates["latest_hba1c"] is None:
                    metadata.pop("latest_hba1c", None)
                else:
                    metadata["latest_hba1c"] = health_updates["latest_hba1c"]
        else:
            metadata = {}

        rows_to_insert.append(
            {
                "user_id": user_id,
                "health_condition_id": condition_id,
            }
        )
        if supports_metadata:
            rows_to_insert[-1]["condition_metadata"] = metadata

    supabase.table("user_health_conditions").delete().eq("user_id", user_id).execute()

    if rows_to_insert:
        supabase.table("user_health_conditions").insert(rows_to_insert).execute()

    return get_user_health_conditions(supabase, user_id)