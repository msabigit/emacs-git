/* Communication module for Android terminals.  -*- c-file-style: "GNU" -*-

Copyright (C) 2023 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.  */

package org.gnu.emacs;

import android.content.Context;

import android.database.Cursor;
import android.database.MatrixCursor;

import android.os.Build;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import static android.provider.DocumentsContract.buildChildDocumentsUri;
import android.provider.DocumentsProvider;

import android.webkit.MimeTypeMap;

import android.net.Uri;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/* ``Documents provider''.  This allows Emacs's home directory to be
   modified by other programs holding permissions to manage system
   storage, which is useful to (for example) correct misconfigurations
   which prevent Emacs from starting up.

   This functionality is only available on Android 19 and later.  */

public class EmacsDocumentsProvider extends DocumentsProvider
{
  /* Home directory.  This is the directory whose contents are
     initially returned to requesting applications.  */
  private File baseDir;

  /* The default projection for requests for the root directory.  */
  private static final String[] DEFAULT_ROOT_PROJECTION;

  /* The default projection for requests for a file.  */
  private static final String[] DEFAULT_DOCUMENT_PROJECTION;

  static
  {
    DEFAULT_ROOT_PROJECTION = new String[] {
      Root.COLUMN_ROOT_ID,
      Root.COLUMN_MIME_TYPES,
      Root.COLUMN_FLAGS,
      Root.COLUMN_TITLE,
      Root.COLUMN_SUMMARY,
      Root.COLUMN_DOCUMENT_ID,
      Root.COLUMN_AVAILABLE_BYTES,
    };

    DEFAULT_DOCUMENT_PROJECTION = new String[] {
      Document.COLUMN_DOCUMENT_ID,
      Document.COLUMN_MIME_TYPE,
      Document.COLUMN_DISPLAY_NAME,
      Document.COLUMN_LAST_MODIFIED,
      Document.COLUMN_FLAGS,
      Document.COLUMN_SIZE,
    };
  }

  @Override
  public boolean
  onCreate ()
  {
    /* Set the base directory to Emacs's files directory.  */
    baseDir = getContext ().getFilesDir ();
    return true;
  }

  @Override
  public Cursor
  queryRoots (String[] projection)
  {
    MatrixCursor result;
    MatrixCursor.RowBuilder row;

    /* If the requestor asked for nothing at all, then it wants some
       data by default.  */

    if (projection == null)
      projection = DEFAULT_ROOT_PROJECTION;

    result = new MatrixCursor (projection);
    row = result.newRow ();

    /* Now create and add a row for each file in the base
       directory.  */
    row.add (Root.COLUMN_ROOT_ID, baseDir.getAbsolutePath ());
    row.add (Root.COLUMN_SUMMARY, "Emacs home directory");

    /* Add the appropriate flags.  */

    row.add (Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE);
    row.add (Root.FLAG_LOCAL_ONLY);
    row.add (Root.COLUMN_TITLE, "Emacs");
    row.add (Root.COLUMN_DOCUMENT_ID, baseDir.getAbsolutePath ());

    return result;
  }

  /* Return the MIME type of a file FILE.  */

  private String
  getMimeType (File file)
  {
    String name, extension, mime;
    int extensionSeparator;

    if (file.isDirectory ())
      return Document.MIME_TYPE_DIR;

    /* Abuse WebView stuff to get the file's MIME type.  */
    name = file.getName ();
    extensionSeparator = name.lastIndexOf ('.');

    if (extensionSeparator > 0)
      {
	extension = name.substring (extensionSeparator + 1);
	mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension (extension);

	if (mime != null)
	  return mime;
      }

    return "application/octet-stream";
  }

  /* Append the specified FILE to the query result RESULT.
     Handle both directories and ordinary files.  */

  private void
  queryDocument1 (MatrixCursor result, File file)
  {
    MatrixCursor.RowBuilder row;
    String fileName, displayName, mimeType;
    int flags;

    row = result.newRow ();
    flags = 0;

    /* fileName is a string that the system will ask for some time in
       the future.  Here, it is just the absolute name of the file.  */
    fileName = file.getAbsolutePath ();

    /* If file is a directory, add the right flags for that.  */

    if (file.isDirectory ())
      {
	if (file.canWrite ())
	  {
	    flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
	    flags |= Document.FLAG_SUPPORTS_DELETE;
	  }
      }
    else if (file.canWrite ())
      {
	/* Apply the correct flags for a writable file.  */
	flags |= Document.FLAG_SUPPORTS_WRITE;
	flags |= Document.FLAG_SUPPORTS_DELETE;

	/* TODO: implement these

	   if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
	     flags |= Document.FLAG_SUPPORTS_RENAME;

	   if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
	     flags |= Document.FLAG_SUPPORTS_REMOVE; */
      }

    displayName = file.getName ();
    mimeType = getMimeType (file);

    row.add (Document.COLUMN_DOCUMENT_ID, fileName);
    row.add (Document.COLUMN_DISPLAY_NAME, displayName);
    row.add (Document.COLUMN_SIZE, file.length ());
    row.add (Document.COLUMN_MIME_TYPE, mimeType);
    row.add (Document.COLUMN_LAST_MODIFIED, file.lastModified ());
    row.add (Document.COLUMN_FLAGS, flags);
  }

  @Override
  public Cursor
  queryDocument (String documentId, String[] projection)
    throws FileNotFoundException
  {
    MatrixCursor result;

    if (projection == null)
      projection = DEFAULT_DOCUMENT_PROJECTION;

    result = new MatrixCursor (projection);
    queryDocument1 (result, new File (documentId));

    return result;
  }

  @Override
  public Cursor
  queryChildDocuments (String parentDocumentId, String[] projection,
		       String sortOrder) throws FileNotFoundException
  {
    MatrixCursor result;
    File directory;

    if (projection == null)
      projection = DEFAULT_DOCUMENT_PROJECTION;

    result = new MatrixCursor (projection);

    /* Try to open the file corresponding to the location being
       requested.  */
    directory = new File (parentDocumentId);

    /* Now add each child.  */
    for (File child : directory.listFiles ())
      queryDocument1 (result, child);

    return result;
  }

  @Override
  public ParcelFileDescriptor
  openDocument (String documentId, String mode,
		CancellationSignal signal) throws FileNotFoundException
  {
    return ParcelFileDescriptor.open (new File (documentId),
				      ParcelFileDescriptor.parseMode (mode));
  }

  @Override
  public String
  createDocument (String documentId, String mimeType,
		  String displayName) throws FileNotFoundException
  {
    File file;
    boolean rc;
    Uri updatedUri;
    Context context;

    context = getContext ();
    file = new File (documentId, displayName);

    try
      {
	rc = false;

	if (Document.MIME_TYPE_DIR.equals (mimeType))
	  {
	    file.mkdirs ();

	    if (file.isDirectory ())
	      rc = true;
	  }
	else
	  {
	    file.createNewFile ();

	    if (file.isFile ()
		&& file.setWritable (true)
		&& file.setReadable (true))
	      rc = true;
	  }

	if (!rc)
	  throw new FileNotFoundException ("rc != 1");
      }
    catch (IOException e)
      {
	throw new FileNotFoundException (e.toString ());
      }

    updatedUri
      = buildChildDocumentsUri ("org.gnu.emacs", documentId);
    /* Tell the system about the change.  */
    context.getContentResolver ().notifyChange (updatedUri, null);

    return file.getAbsolutePath ();
  }

  private void
  deleteDocument1 (File child)
  {
    File[] children;

    /* Don't delete symlinks recursively.

       Calling readlink or stat is problematic due to file name
       encoding problems, so try to delete the file first, and only
       try to delete files recursively afterword.  */

    if (child.delete ())
      return;

    children = child.listFiles ();

    if (children != null)
      {
	for (File file : children)
	  deleteDocument1 (file);
      }

    child.delete ();
  }

  @Override
  public void
  deleteDocument (String documentId)
    throws FileNotFoundException
  {
    File file, parent;
    File[] children;
    Uri updatedUri;
    Context context;

    /* Java makes recursively deleting a file hard.  File name
       encoding issues also prevent easily calling into C...  */

    context = getContext ();
    file = new File (documentId);
    parent = file.getParentFile ();

    if (parent == null)
      throw new RuntimeException ("trying to delete file without"
				  + " parent!");

    updatedUri
      = buildChildDocumentsUri ("org.gnu.emacs",
			        parent.getAbsolutePath ());

    if (file.delete ())
      {
	/* Tell the system about the change.  */
	context.getContentResolver ().notifyChange (updatedUri, null);
	return;
      }

    children = file.listFiles ();

    if (children != null)
      {
	for (File child : children)
	  deleteDocument1 (child);
      }

    if (file.delete ())
      /* Tell the system about the change.  */
      context.getContentResolver ().notifyChange (updatedUri, null);
  }

  @Override
  public void
  removeDocument (String documentId, String parentDocumentId)
    throws FileNotFoundException
  {
    deleteDocument (documentId);
  }
}