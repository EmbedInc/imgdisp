{   Input images handling.
}
module idisp_image;
define image_next;
define image_open;
define image_close;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Function IMAGE_NEXT
*
*   Advance to the next image in the IMG_LIST list.  The function returns TRUE
*   if advanced to the next image.  It returns FALSE when there is no next image
*   to advance to.  In that case, the IMG_LIST position remains unchanged.
}
function image_next                    {advance to next input image}
  :boolean;                            {TRUE advanced, FALSE no image to advance to}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  image_next := true;                  {init to did advance to next image}

  if img_list.curr = img_list.n then begin {currently at last image in list ?}
    if auto_loop then begin            {list is circular ?}
      image_close (stat);              {make sure existing image is closed}
      sys_error_abort (stat, '', '', nil, 0);
      string_list_pos_abs (img_list, 1); {go to first list entry}
      return;
      end;
    image_next := false;               {no image to advance to}
    return;
    end;

  image_close (stat);                  {make sure old image is closed}
  sys_error_abort (stat, '', '', nil, 0);
  string_list_pos_rel (img_list, 1);   {advance to next image in the list}
  end;
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
