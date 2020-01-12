{   Input images handling.
}
module idisp_image;
define image_open;
define image_close;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Local subroutine IMAGE_OPEN (STAT)
*
*   Make sure that the current input image is open on IMG.  The current image is
*   the one indicated by the current IMG_LIST entry.
}
procedure image_open (                 {make sure current image is open}
  out     stat: sys_err_t);
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if img_open then return;             {image already open, nothing to do ?}

  img_open_read_img (img_list.str_p^, img, stat); {try to open new image file}
  if sys_error(stat) then return;      {error opening image file ?}
  img_open := true;                    {indicate the current image is open}

  file_info (                          {get info about newly opened image file}
    img.tnam,                          {name of file inquiring about}
    [file_iflag_dtm_k],                {we are requesting last modified time stamp}
    imgfile_info,                      {returned date/time info}
    stat);
  end;
{
********************************************************************************
*
*   Local subroutine CLOSE_IMAGE (STAT)
*
*   Make sure no input image is open.
}
procedure image_close (                {make sure no input image is open}
  out     stat: sys_err_t);
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if not img_open then return;         {no image open, nothing to do ?}

  img_close (img, stat);               {close the currently displayed image file}
  if sys_error(stat) then return;
  img_open := false;                   {indicate image file is now closed}
  end;
