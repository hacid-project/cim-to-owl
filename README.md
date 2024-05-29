# cim-to-owl
Converting ES-DOC data, based on the Common Information Model (CIM), to RDF.

## Background

A number of umbrella climate science projects aim at collecting, organizing, and comparing the climate modelling efforts carried on by groups and institutions across the world.
An important international project of this kind is the [Coupled Model Intercomparison Project (CMIP)](https://wcrp-cmip.org/), which runs since 1995.


The [Earth System Documentation (ES-DOC)](https://es-doc.org/) initiative aims at collecting metadata related to multiple climate science projects (notably, last editions of the CMIP series), representing it in a structured and well-defined model: the [Common Information Model (CIM)](https://github.com/ES-DOC/esdoc-cim).

Unfortunately CIM is not directly interoperable with other models/formats for structured data. Furthermore, so far CIM has been adopted only for ES-DOC (to the best of the author's knowledge).

## Goal

This repository provides a set of scripts to represent ES-DOC model (CIM) and data using interoperable semantic web standards like RDF, RDFS, and OWL.

Mapping CIM to RDF requires matching CIM concepts to corresponding terms in RDF vocabularies, which could be pre-existing or created ad hoc for the purpose.

The approach adopted here is meant to be incremental and data-centric: an initial default RDF representation and mapping is built from CIM, which can be used to convert the data to RDF; the data can thus be quickly accessed as an RDF graph; the RDF vocabulary and mapping (which can be configured to use existing vocabularies) can be incrementally refined as needed.

## Usage

To be documented soon...