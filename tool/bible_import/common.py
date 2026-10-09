# -*- coding: utf-8 -*-
"""Gemeinsame Pfade und Einstellungen des Bibel-Imports.

Alles Heruntergeladene liegt im nicht versionierten Verzeichnis
``build/content_import/bible`` und kann jederzeit neu geladen werden.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CACHE = os.path.join(REPO, 'build', 'content_import', 'bible')
ASSETS = os.path.join(REPO, 'assets', 'bible')
NOTICES = os.path.join(REPO, 'docs', 'bible-sources')

UA = 'Mozilla/5.0 (theologie.app content import)'


def config():
    with open(os.path.join(HERE, 'sources.json'), encoding='utf-8') as f:
        return json.load(f)


def cache(*parts):
    path = os.path.join(CACHE, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path
