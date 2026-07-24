"""Identity helpers: cosine similarity for speaker matching."""

import numpy as np


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity between two normalized vectors.

    Assumes inputs are already normalized to unit length.
    Returns value in [-1, 1], where 1 means identical.
    """
    # For normalized vectors, cosine similarity is just dot product
    return float(np.dot(a, b))
