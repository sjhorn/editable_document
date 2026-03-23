// Copyright 2026 Scott Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/painting.dart';

/// Creates a [FileImage] for the given file path.
ImageProvider? createFileImageProvider(String path) => FileImage(File(path));
