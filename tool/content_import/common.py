# -*- coding: utf-8 -*-
"""Gemeinsame Pfade der Import-Werkzeuge.

Die Werkzeuge erzeugen ``assets/confessions.json`` aus öffentlich zugänglichen
Quellen. Alles Heruntergeladene liegt im nicht versionierten Verzeichnis
``build/content_import`` und kann jederzeit neu erzeugt werden.
"""
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CACHE = os.path.join(REPO, 'build', 'content_import')


def cache(*parts):
    path = os.path.join(CACHE, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def repo(*parts):
    return os.path.join(REPO, *parts)
